import type { IControl, Map as MapLibreMap, Marker } from 'maplibre-gl';

type MapLibre = typeof import('maplibre-gl');

// [longitude, latitude], as MapLibre takes it
type Point = [number, number];

// The point moves at most this far (in meters) from where the map got it, so
// it stays at its address
const MOVE_RADIUS = 300;

// A charging station of the tiles within this distance (in meters) of the
// point can take it
const STATION_RADIUS = 150;

// A point closer than this (in meters) stands on the station already
const ON_STATION = 10;

// A station on the edge of two tiles comes in both, so two stations closer
// than this (in meters) are one
const SAME_STATION = 20;

// The texts of the map (see Car::Map::Component#movable_texts). The label of
// the button has "{name}" for the name of the station.
export interface MovablePointTexts {
  hint: string;
  station: string;
  unnamedStation: string;
}

export interface MovablePointOptions {
  color: string;
  stroke: string;
  radius: number;
  strokeWidth: number;
  texts: MovablePointTexts;
  onMove: (point: Point) => void;
}

interface Station {
  point: Point;
  name?: string;
}

// A control of MapLibre that holds one element
class ElementControl implements IControl {
  constructor(private readonly element: HTMLElement) {}

  onAdd() {
    return this.element;
  }

  onRemove() {
    this.element.remove();
  }
}

// The point of the form of an offsite charging session (see
// Car::Map::Component), which the user moves to where the car charged: with a
// drag, or with a click on the map. The address gives a position near the
// station, often on the building of the address. The tiles know the charging
// stations, so the map offers the one station near the point, without a
// request to a geocoder.
export default class MovablePoint {
  private readonly origin: Point;
  private point: Point;
  private readonly marker: Marker;
  // The point of the station near the origin and the control with its
  // button, from the tiles once they are loaded
  private station?: { point: Point; control: HTMLElement };
  private readonly form: HTMLFormElement | null;

  constructor(
    private readonly lib: MapLibre,
    private readonly map: MapLibreMap,
    point: Point,
    private readonly options: MovablePointOptions,
  ) {
    this.origin = point;
    this.point = point;

    this.marker = new lib.Marker({ element: this.dot(), draggable: true })
      .setLngLat(point)
      .addTo(map);
    this.marker.on('dragend', () => {
      const { lng, lat } = this.marker.getLngLat();
      this.moveTo([lng, lat]);
    });
    map.on('click', ({ lngLat }) => this.moveTo([lngLat.lng, lngLat.lat]));

    this.form = map.getContainer().closest('form');
    this.form?.addEventListener('reset', this.reset);

    const hint = document.createElement('div');
    hint.className = 'maplibregl-ctrl car-map-hint';
    hint.textContent = options.texts.hint;
    map.addControl(new ElementControl(hint), 'bottom-left');

    // The view then shows the point and the station, so the user sees where
    // the button leads. The user can move the point before the tiles load.
    map.once('idle', () => {
      const station = this.nearStation();
      if (!station) return;

      const control = this.buildStationControl(station);
      this.station = { point: station.point, control };
      map.addControl(new ElementControl(control), 'top-left');
      this.offerStation();
      const bounds = new lib.LngLatBounds(this.point, this.point);
      map.fitBounds(bounds.extend(station.point), {
        padding: 60,
        maxZoom: map.getZoom(),
      });
    });
  }

  setStroke(color: string) {
    this.marker.getElement().style.borderColor = color;
  }

  remove() {
    this.form?.removeEventListener('reset', this.reset);
  }

  // A reset of the form, like its discard button, puts the point back where
  // the map got it. The form brings back its fields itself.
  private readonly reset = () => {
    this.place(this.origin);
  };

  // A point too far from its address goes back
  private moveTo(point: Point) {
    if (this.distance(point, this.origin) > MOVE_RADIUS) {
      this.marker.setLngLat(this.point);
      return;
    }

    this.place(point);
    this.options.onMove(point);
  }

  private place(point: Point) {
    this.point = point;
    this.marker.setLngLat(point);
    if (!this.map.getBounds().contains(point))
      this.map.easeTo({ center: point });
    this.offerStation();
  }

  // The button shows while the point is not on the station
  private offerStation() {
    if (!this.station) return;

    this.station.control.hidden =
      this.distance(this.station.point, this.point) <= ON_STATION;
  }

  // A control with the button, which names the station
  private buildStationControl(station: Station): HTMLElement {
    const { texts } = this.options;
    const button = document.createElement('button');
    button.type = 'button';
    // A function takes the name as it is, without the "$" patterns of replace
    const name = station.name;
    button.textContent = name
      ? texts.station.replace('{name}', () => name)
      : texts.unnamedStation;
    button.addEventListener('click', (event) => {
      event.stopPropagation();
      this.moveTo(station.point);
    });

    const group = document.createElement('div');
    group.className = 'maplibregl-ctrl maplibregl-ctrl-group car-map-station';
    group.append(button);
    return group;
  }

  // The one charging station of the tiles near the origin, or undefined for
  // none or more than one
  private nearStation(): Station | undefined {
    const stations: Station[] = [];
    const features = this.map.querySourceFeatures('openmaptiles', {
      sourceLayer: 'poi',
      filter: ['==', ['get', 'subclass'], 'charging_station'],
    });

    for (const feature of features) {
      if (feature.geometry.type !== 'Point') continue;

      const point = feature.geometry.coordinates as Point;
      if (this.distance(point, this.origin) > STATION_RADIUS) continue;
      if (stations.some((it) => this.distance(it.point, point) < SAME_STATION))
        continue;

      stations.push({ point, name: feature.properties.name as string });
    }

    return stations.length === 1 ? stations[0] : undefined;
  }

  private distance(from: Point, to: Point): number {
    return new this.lib.LngLat(...from).distanceTo(new this.lib.LngLat(...to));
  }

  // The marker looks like the point of the live map, and the hand shows that
  // it moves
  private dot(): HTMLElement {
    const { color, stroke, radius, strokeWidth, texts } = this.options;
    const dot = document.createElement('div');
    dot.title = texts.hint;
    Object.assign(dot.style, {
      width: `${2 * (radius + strokeWidth)}px`,
      height: `${2 * (radius + strokeWidth)}px`,
      borderRadius: '50%',
      background: color,
      border: `${strokeWidth}px solid ${stroke}`,
      cursor: 'grab',
    });
    return dot;
  }
}
