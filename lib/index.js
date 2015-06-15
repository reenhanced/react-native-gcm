'use strict';

var _inherits = require('babel-runtime/helpers/inherits')['default'];

var _get = require('babel-runtime/helpers/get')['default'];

var _createClass = require('babel-runtime/helpers/create-class')['default'];

var _classCallCheck = require('babel-runtime/helpers/class-call-check')['default'];

var _Object$defineProperty = require('babel-runtime/core-js/object/define-property')['default'];

var _interopRequireDefault = require('babel-runtime/helpers/interop-require-default')['default'];

_Object$defineProperty(exports, '__esModule', {
  value: true
});

var _reactNative = require('react-native');

var _bh5Emitter = require('bh5-emitter');

var _bh5Emitter2 = _interopRequireDefault(_bh5Emitter);

var _NativeModules = require('NativeModules');

var Client = (function (_EventEmitter) {
  function Client() {
    var _this = this;

    _classCallCheck(this, Client);

    _get(Object.getPrototypeOf(Client.prototype), 'constructor', this).call(this);
    this._gcm = _NativeModules.GCM;
    _reactNative.DeviceEventEmitter.addListener('GCMEvent', function (e) {
      _this.emit(e.type, e.data);
    });
  }

  _inherits(Client, _EventEmitter);

  _createClass(Client, [{
    key: 'register',
    value: function register() {
      this._gcm.register();
    }
  }, {
    key: 'unregister',
    value: function unregister(fn) {
      var cb = fn ? fn : function () {};
      this._gcm.unregister(function (res) {
        var err = res.error ? new Error(res.error) : null;
        cb(err, res);
      });
    }
  }, {
    key: 'topicSubscribe',
    value: function topicSubscribe(topic, fn) {
      var cb = fn ? fn : function () {};
      this._gcm.topicSubscribe(topic, function (res) {
        var err = res.error ? new Error(res.error) : null;
        cb(err, res);
      });
    }
  }, {
    key: 'topicUnsubscribe',
    value: function topicUnsubscribe(topic, fn) {
      var cb = fn ? fn : function () {};
      this._gcm.topicUnsubscribe(topic, function (res) {
        var err = res.error ? new Error(res.error) : null;
        cb(err, res);
      });
    }
  }, {
    key: 'sendMessage',
    value: function sendMessage(data) {
      this._gcm.sendMessage(data);
    }
  }]);

  return Client;
})(_bh5Emitter2['default']);

exports.Client = Client;
exports['default'] = new Client();