import '@hotwired/turbo-rails';
import.meta.glob('../channels/**/*_channel.{js,ts}', { eager: true });

import '../utils/setupHoneyBadger';
import '../utils/setupStimulus';
import '../utils/preventContextmenu';

import '../stylesheets/application.css';
