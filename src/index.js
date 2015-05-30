'use strict';

import React, { DeviceEventEmitter } from 'react-native';
import EventEmitter from 'bh5-emitter';
import { GCM } from 'NativeModules';

export class Client extends EventEmitter {
  constructor() {
    super();
    this._gcm = GCM;
    DeviceEventEmitter.addListener('GCMEvent', (e) => {
      this.emit(e.type, e.data);
    });
  }

  register() {
    this._gcm.register();
  }
}


export default new Client();
