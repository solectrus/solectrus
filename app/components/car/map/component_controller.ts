import { Controller } from '@hotwired/stimulus';
import type {
  ExpressionSpecification,
  GeoJSONSource,
  Map as MapLibreMap,
  MapLayerMouseEvent,
  Popup,
} from 'maplibre-gl';

type MapLibre = typeof import('maplibre-gl');

// [latitude, longitude, share of the time of the cars from 0 to 1, the id of
// the place]. The live marker has no id.
type Place = [number, number, number, number?];

// The places of one car, or the places of all cars of a period
interface CarPlaces {
  places: Place[];
}

// The color of each place, indigo-500. The color of a car marks the car and
// not its places.
const COLOR = '#6366f1';

// The edge of a circle. On the dark map, the color has too little contrast,
// so the edge has the color of the muted text (slate-300). The live marker
// has a white halo on the light map.
const STROKE = {
  period: { light: COLOR, dark: '#cbd5e1' },
  live: { light: '#ffffff', dark: '#cbd5e1' },
};

interface PlaceFeature {
  type: 'Feature';
  geometry: { type: 'Point'; coordinates: [number, number] };
  properties: {
    placeId: number;
    share: number;
  };
}

const STYLES = {
  light: 'https://tiles.openfreemap.org/styles/positron',
  dark: 'https://tiles.openfreemap.org/styles/dark',
};

const LAYER = 'places';

// How long the pointer rests on a place before the map loads its tooltip. A
// pointer that only passes by loads nothing, so it does not ask Nominatim for
// the name of each place on its way.
const LOAD_DELAY = 100;

// How long the tooltip stays after the pointer leaves its place, so the
// pointer can reach the link in the tooltip
const HIDE_DELAY = 200;

// How long the tooltip takes to grow from the spinner to the size of its
// content, and then to fade in the content
const TOOLTIP_GROWTH = 150;
const TOOLTIP_FADE = 150;

// The side of the place where MapLibre puts the tip of a tooltip, for
// example "bottom" or "top-left"
function anchorOf(container: HTMLElement): string {
  const prefix = 'maplibregl-popup-anchor-';
  const name = [...container.classList].find((it) => it.startsWith(prefix));
  return name?.slice(prefix.length) ?? '';
}

// The shift from the box of the tooltip at its new anchor to the box `from`
// at its old anchor, when the box has its size `from`. The box grows away
// from its tip: to the right of a tip on the left, below a tip on the top.
function glide(from: DOMRect, to: DOMRect, anchor: string): [number, number] {
  let x = 0;
  if (anchor.includes('left')) x = 1;
  else if (anchor.includes('right')) x = -1;
  let y = 0;
  if (anchor.startsWith('top')) y = 1;
  else if (anchor.startsWith('bottom')) y = -1;

  const startX = to.x + to.width / 2 - ((to.width - from.width) / 2) * x;
  const startY = to.y + to.height / 2 - ((to.height - from.height) / 2) * y;
  return [from.x + from.width / 2 - startX, from.y + from.height / 2 - startY];
}

const ZOOM = { live: 14, single: 13, max: 14 };

// The view of a map without a place, like the map of a guest: Western Europe
// from Portugal to Poland, as [west, south] and [east, north]
const DEFAULT_BOUNDS: [[number, number], [number, number]] = [
  [-10, 36],
  [20, 58],
];

// The points of interest of the tiles, so the user can name a place after
// what stands there. The styles of OpenFreeMap share the sprite with their
// icons, but only the colorful style shows them. A point without a name is
// mostly a waste basket or a bollard, so the map leaves it out.
const POI_LAYER = 'poi';

// The labels of the points in the muted colors of the style
const POI_TEXT = { light: '#666666', dark: '#8a8a8a' };
const POI_HALO = { light: '#ffffff', dark: 'rgba(0,0,0,0.7)' };

// The dark style draws the roads almost in the color of the background, so
// the map draws them lighter, the major roads lighter than the minor ones
const DARK_ROADS = {
  highway_path: '#2e2e2e',
  highway_minor: '#383838',
  highway_major_casing: '#5c5c5c',
  highway_major_inner: '#454545',
  highway_motorway_casing: '#666666',
  highway_motorway_inner: '#4d4d4d',
};

// MapLibre is large, so only a map loads it, and only once. Its worker comes
// from Vite, because the bundle does not keep the file next to the module,
// where MapLibre looks for it.
let maplibre: Promise<MapLibre> | undefined;

function loadMapLibre(): Promise<MapLibre> {
  maplibre ??= Promise.all([
    import('maplibre-gl'),
    import('maplibre-gl/dist/maplibre-gl-worker.mjs?worker&url'),
    import('maplibre-gl/dist/maplibre-gl.css'),
  ]).then(([lib, worker]) => {
    lib.setWorkerUrl(worker.default);
    return lib;
  });

  return maplibre;
}

const isDark = () => document.documentElement.classList.contains('dark');

export default class extends Controller<HTMLElement> {
  static readonly targets = ['container', 'loading'];

  static readonly values = {
    cars: Array,
    live: Boolean,
    tooltipUrl: String,
    unknownPlace: String,
  };

  declare readonly containerTarget: HTMLElement;
  declare readonly loadingTarget: HTMLTemplateElement;
  declare readonly carsValue: CarPlaces[];
  declare readonly liveValue: boolean;
  declare readonly tooltipUrlValue: string;
  declare readonly unknownPlaceValue: string;

  private lib?: MapLibre;
  private map?: MapLibreMap;
  private popup?: Popup;
  private dark = isDark();

  // The tooltips that the map loaded, as HTML by the id of the place. A
  // failed request is null, so the map loads each tooltip once.
  private readonly tooltips = new Map<number, string | null>();
  private hovered?: number;
  private loadTimer?: number;
  private hideTimer?: number;
  private loading = false;

  async connect() {
    const lib = await loadMapLibre();
    // The element can be gone, or have a map already, when MapLibre arrives
    if (!this.element.isConnected || this.map) return;

    this.lib = lib;
    this.containerTarget.replaceChildren();
    this.map = new lib.Map({
      container: this.containerTarget,
      style: this.styleUrl,
      attributionControl: { compact: true },
      bounds: DEFAULT_BOUNDS,
    });
    this.fit();

    // The styles of OpenFreeMap name icons that their sprite does not have,
    // for example "circle-11". An empty image hides them without a warning.
    const map = this.map;
    map.setMissingStyleImageResolver((id) => {
      if (!map.hasImage(id))
        map.addImage(id, { width: 1, height: 1, data: new Uint8Array(4) });
    });

    // A new style drops the places and the language, so each style gets them
    // again
    this.map.on('style.load', () => {
      this.lightenRoads();
      this.showPointsOfInterest();
      this.localizeLabels();
      this.showPlaces();
    });

    // MapLibre opens the attribution when the data of the style arrives, and
    // closes it on the first drag. The map starts with the attribution closed,
    // and its info button opens it. This listener runs in the same event,
    // after the one of MapLibre, so the open attribution never shows.
    const closeAttribution = () => {
      if (!this.containerTarget.querySelector('.maplibregl-compact-show'))
        return;

      this.closeAttribution();
      map.off('styledata', closeAttribution);
      map.off('sourcedata', closeAttribution);
    };
    map.on('styledata', closeAttribution);
    map.on('sourcedata', closeAttribution);
    map.on('drag', () => this.closeAttribution());
    document.addEventListener('keydown', this.handleKeydown, true);

    if (!this.liveValue) {
      this.map.on('mousemove', LAYER, (event) => this.showPopup(event));
      this.map.on('click', LAYER, (event) => this.showPopup(event));
      this.map.on('mouseleave', LAYER, () => this.scheduleHide());
    }

    document.addEventListener('theme:changed', this.switchTheme);
  }

  disconnect() {
    document.removeEventListener('keydown', this.handleKeydown, true);
    window.clearTimeout(this.loadTimer);
    window.clearTimeout(this.hideTimer);
    document.removeEventListener('theme:changed', this.switchTheme);
    this.popup?.remove();
    this.map?.remove();
    this.map = undefined;
  }

  // The attribution is a <details> element, and MapLibre keeps it `open`
  // while it is closed. A modal ignores ESC while it has an open <details>,
  // so the attribution removes `open` together with its class. Returns
  // whether the attribution was open.
  private closeAttribution(): boolean {
    const attribution = this.containerTarget.querySelector('details');
    if (!attribution?.open) return false;

    attribution.open = false;
    attribution.classList.remove('maplibregl-compact-show');
    return true;
  }

  // ESC closes an open attribution first, like the pickers in a modal
  private readonly handleKeydown = (event: KeyboardEvent) => {
    if (event.key !== 'Escape' || !this.closeAttribution()) return;

    event.preventDefault();
    event.stopPropagation();
  };

  private get styleUrl(): string {
    return this.dark ? STYLES.dark : STYLES.light;
  }

  // The theme selector announces each switch of the theme
  private readonly switchTheme = () => {
    if (isDark() === this.dark) return;

    this.dark = isDark();
    // Without a diff, MapLibre loads the full style and fires style.load
    this.map?.setStyle(this.styleUrl, { diff: false });
  };

  private lightenRoads() {
    const map = this.map;
    if (!map || !this.dark) return;

    for (const [id, color] of Object.entries(DARK_ROADS)) {
      if (map.getLayer(id)) map.setPaintProperty(id, 'line-color', color);
    }
  }

  // The points of interest below the places of the cars. Their labels get
  // the language of the page (see localizeLabels).
  private showPointsOfInterest() {
    const map = this.map;
    if (!map || map.getLayer(POI_LAYER)) return;

    const theme = this.dark ? 'dark' : 'light';
    map.addLayer({
      id: POI_LAYER,
      type: 'symbol',
      source: 'openmaptiles',
      'source-layer': 'poi',
      minzoom: 16,
      filter: ['has', 'name'],
      layout: {
        // Where the labels overlap, the important points win. The rank of a
        // point is lower the more important it is.
        'symbol-sort-key': ['get', 'rank'],
        'icon-image': ['get', 'class'],
        'text-field': ['get', 'name'],
        'text-font': ['Noto Sans Regular'],
        'text-size': 11,
        'text-anchor': 'top',
        'text-offset': [0, 0.6],
        'text-max-width': 9,
      },
      paint: {
        'icon-opacity': this.dark ? 0.6 : 0.8,
        'text-color': POI_TEXT[theme],
        'text-halo-color': POI_HALO[theme],
        'text-halo-width': 1,
      },
    });
  }

  // The styles of OpenFreeMap label places with their English name. The tiles
  // also have the name in each language ("name:de"), so the labels take the
  // language of the page, then the Latin name, then the local name. A label
  // without a name, like the number of a road, stays.
  private localizeLabels() {
    const map = this.map;
    if (!map) return;

    const language = document.documentElement.lang || 'en';
    const label: ExpressionSpecification = [
      'coalesce',
      ['get', `name:${language}`],
      ['get', 'name:latin'],
      ['get', 'name'],
    ];

    for (const layer of map.getStyle().layers) {
      if (layer.type !== 'symbol') continue;

      const field = map.getLayoutProperty(layer.id, 'text-field');
      if (JSON.stringify(field)?.includes('"name')) {
        map.setLayoutProperty(layer.id, 'text-field', label);
      }
    }
  }

  private get points(): Place[] {
    return this.carsValue.flatMap((car) => car.places);
  }

  private get geojson(): {
    type: 'FeatureCollection';
    features: PlaceFeature[];
  } {
    return {
      type: 'FeatureCollection',
      features: this.points.map(([latitude, longitude, share, id]) => ({
        type: 'Feature',
        geometry: { type: 'Point', coordinates: [longitude, latitude] },
        properties: { placeId: id ?? 0, share },
      })),
    };
  }

  private get stroke(): string {
    return STROKE[this.liveValue ? 'live' : 'period'][
      this.dark ? 'dark' : 'light'
    ];
  }

  private showPlaces() {
    const map = this.map;
    if (!map) return;

    const source = map.getSource<GeoJSONSource>(LAYER);
    if (source) {
      source.setData(this.geojson);
      return;
    }

    map.addSource(LAYER, { type: 'geojson', data: this.geojson });
    map.addLayer({
      id: LAYER,
      type: 'circle',
      source: LAYER,
      paint: this.liveValue ? this.livePaint : this.periodPaint,
    });
  }

  // The area of a circle grows with the share of the time at its place
  private get periodPaint() {
    const radius: ExpressionSpecification = [
      'interpolate',
      ['linear'],
      ['sqrt', ['get', 'share']],
      0,
      4,
      1,
      24,
    ];

    return {
      'circle-radius': radius,
      'circle-color': COLOR,
      'circle-opacity': 0.5,
      'circle-stroke-color': this.stroke,
      'circle-stroke-width': 1.5,
    };
  }

  private get livePaint() {
    return {
      'circle-radius': 9,
      'circle-color': COLOR,
      'circle-stroke-color': this.stroke,
      'circle-stroke-width': 3,
    };
  }

  private fit() {
    const map = this.map;
    const lib = this.lib;
    const points = this.points;
    if (!map || !lib || points.length === 0) return;

    if (points.length === 1) {
      const [latitude, longitude] = points[0];
      map.jumpTo({
        center: [longitude, latitude],
        zoom: this.liveValue ? ZOOM.live : ZOOM.single,
      });
      return;
    }

    const bounds = new lib.LngLatBounds();
    for (const [latitude, longitude] of points) {
      bounds.extend([longitude, latitude]);
    }
    map.fitBounds(bounds, { padding: 40, maxZoom: ZOOM.max, animate: false });
  }

  private showPopup(event: MapLayerMouseEvent) {
    const map = this.map;
    const feature = event.features?.[0];
    if (!map || !this.lib || !feature) return;

    const { placeId } = feature.properties as PlaceFeature['properties'];
    const [longitude, latitude] = (feature.geometry as PlaceFeature['geometry'])
      .coordinates;

    map.getCanvas().style.cursor = 'pointer';
    window.clearTimeout(this.hideTimer);
    this.popup ??= this.createPopup(this.lib);
    if (this.hovered !== placeId || !this.popup.isOpen()) {
      this.hovered = placeId;
      this.popup
        .setLngLat([longitude, latitude])
        .setDOMContent(this.tooltip(placeId))
        .addTo(map);
    }

    this.scheduleLoad(event.type === 'click' ? 0 : LOAD_DELAY);
  }

  // The tooltip stays while the pointer is on it, so the pointer can use its
  // links. It does not take the focus.
  private createPopup(lib: MapLibre): Popup {
    const popup = new lib.Popup({
      closeButton: false,
      closeOnClick: false,
      focusAfterOpen: false,
      maxWidth: '280px',
      className: 'car-map-popup',
    });
    // MapLibre builds the element anew each time the tooltip opens
    popup.on('open', () => {
      const element = popup.getElement();
      element.addEventListener('mouseenter', () =>
        window.clearTimeout(this.hideTimer),
      );
      // A tooltip that glides away from the pointer leaves it on its place,
      // and the map gets no move of the pointer then
      element.addEventListener('mouseleave', (event) => {
        if (!this.isOverPlace(event)) this.scheduleHide();
      });
    });

    return popup;
  }

  // The link to the form of the place opens the modal and closes the
  // tooltip, after Turbo has the link
  closeTooltip() {
    window.setTimeout(() => this.hidePopup());
  }

  private isOverPlace(event: MouseEvent): boolean {
    const map = this.map;
    if (!map) return false;

    const canvas = map.getCanvas().getBoundingClientRect();
    const point: [number, number] = [
      event.clientX - canvas.left,
      event.clientY - canvas.top,
    ];
    return map.queryRenderedFeatures(point, { layers: [LAYER] }).length > 0;
  }

  private scheduleHide() {
    window.clearTimeout(this.hideTimer);
    this.hideTimer = window.setTimeout(() => this.hidePopup(), HIDE_DELAY);
  }

  private hidePopup() {
    window.clearTimeout(this.hideTimer);
    window.clearTimeout(this.loadTimer);
    this.hovered = undefined;
    if (this.map) this.map.getCanvas().style.cursor = '';
    this.popup?.remove();
  }

  // Loads the tooltip of the hovered place, unless the map has it. One
  // request at a time, and the next one waits for the pointer to rest.
  private scheduleLoad(delay: number) {
    window.clearTimeout(this.loadTimer);

    const id = this.hovered;
    if (!id || this.tooltips.has(id) || !this.tooltipUrlValue) return;

    this.loadTimer = window.setTimeout(() => void this.load(id), delay);
  }

  private async load(id: number) {
    if (this.loading || this.hovered !== id) return;

    let html: string | null = null;
    this.loading = true;
    try {
      const response = await fetch(
        this.tooltipUrlValue.replace(':id', String(id)),
        { headers: { Accept: 'text/html' } },
      );
      if (response.ok) html = await response.text();
    } catch {
      // The tooltip names an unknown place
    } finally {
      this.tooltips.set(id, html);
      this.loading = false;
    }

    if (this.hovered === id) this.growTooltip(this.tooltip(id));
    this.scheduleLoad(LOAD_DELAY);
  }

  // The tooltip grows from the size of the spinner to the size of its content,
  // and then the content fades in. While the tooltip grows, the content is
  // hidden and has its final width, so its lines do not break anew. MapLibre
  // keeps the element of the content and places the tooltip by a share of its
  // size, so the tip stays at the place.
  //
  // A larger tooltip can need another side of the place, and MapLibre then
  // moves its tip to that side (the anchor). The tooltip then glides from its
  // old position, and its tip fades in with the content.
  private growTooltip(content: Node) {
    const popup = this.popup;
    const container = popup?.getElement();
    const box = container?.querySelector<HTMLElement>(
      '.maplibregl-popup-content',
    );
    if (!popup || !container || !box) return;

    const anchor = anchorOf(container);
    const from = box.getBoundingClientRect();
    popup.setDOMContent(content);
    const inner = box.firstElementChild as HTMLElement | null;
    if (!inner || window.matchMedia('(prefers-reduced-motion: reduce)').matches)
      return;

    const to = box.getBoundingClientRect();
    const growth = { duration: TOOLTIP_GROWTH, easing: 'ease-out' };
    const fade = { duration: TOOLTIP_FADE, easing: 'ease-out' };
    const faded: HTMLElement[] = [inner];

    inner.style.width = `${inner.getBoundingClientRect().width}px`;
    box.style.overflow = 'hidden';
    box.animate(
      [
        { width: `${from.width}px`, height: `${from.height}px` },
        { width: `${to.width}px`, height: `${to.height}px` },
      ],
      growth,
    );

    const newAnchor = anchorOf(container);
    if (newAnchor !== anchor) {
      const [dx, dy] = glide(from, to, newAnchor);
      container.animate(
        [{ translate: `${dx}px ${dy}px` }, { translate: '0 0' }],
        growth,
      );
      const tip = container.querySelector<HTMLElement>('.maplibregl-popup-tip');
      if (tip) faded.push(tip);
    }

    for (const element of faded) element.style.opacity = '0';
    window.setTimeout(() => {
      box.style.removeProperty('overflow');
      inner.style.removeProperty('width');
      for (const element of faded) {
        element.style.removeProperty('opacity');
        element.animate([{ opacity: 0 }, { opacity: 1 }], fade);
      }
    }, TOOLTIP_GROWTH);
  }

  // The tooltip from the server. Until it comes, a spinner smaller than each
  // tooltip (see Car::Map::Component). A failed request names an unknown
  // place.
  private tooltip(id: number): Node {
    const html = this.tooltips.get(id);
    if (html) {
      const template = document.createElement('template');
      template.innerHTML = html;
      return template.content;
    }
    if (html === undefined) return this.loadingTarget.content.cloneNode(true);

    const title = document.createElement('div');
    title.className = 'font-semibold';
    title.textContent = this.unknownPlaceValue;
    return title;
  }
}
