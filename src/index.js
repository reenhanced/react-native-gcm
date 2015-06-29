'use strict';

import { DeviceEventEmitter, NativeModules } from 'react-native';
import EventEmitter from 'bh5-emitter';

let { GCM } = NativeModules;

export class Client extends EventEmitter {
  constructor() {
    super();
    this._gcm = GCM;
    DeviceEventEmitter.addListener('GCMEvent', (e) => {
      this.emit(e.type, e.data);
    });
  }

  register(permissions) {
    let opts = {};
    if (permissions) {
      opts.alert = !!permissions.alert;
      opts.badge = !!permissions.badge;
      opts.sound = !!permissions.sound;
    } else {
      opts = {
        alert: true,
        badge: true,
        sound: true,
      };
    }
    this._gcm.register(opts);
  }

  unregister(fn) {
    let cb = fn ? fn : () => {};
    this._gcm.unregister((res) => {
      let err = res.error ? new Error(res.error) : null;
      cb(err, res);
    });
  }

  setAppBadge(val, increment, fn) {
    if (typeof increment === 'function') {
      fn = increment;
      increment = false;
    }

    let cb = fn ? fn : () => {};
    this._gcm.setAppBadge(Math.abs(val), !!increment, ((badgeVal) => {
      cb(badgeVal);
    }));
  }

  getAppBadge(fn) {
    let cb = fn ? fn : () => {};
    return this._gcm.getAppBadge((badgeVal) => {
      cb(badgeVal);
    });
  }

  topicSubscribe(topic, fn) {
    let cb = fn ? fn : () => {};
    this._gcm.topicSubscribe(topic, (res) => {
      let err = res.error ? new Error(res.error) : null;
      cb(err, res);
    });
  }

  topicUnsubscribe(topic, fn) {
    let cb = fn ? fn : () => {};
    this._gcm.topicUnsubscribe(topic, (res) => {
      let err = res.error ? new Error(res.error) : null;
      cb(err, res);
    });
  }

  sendMessage(data) {
    this._gcm.sendMessage(data);
  }
}

export default new Client();
