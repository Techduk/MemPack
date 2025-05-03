import TestJson from "res://config/test.json";

export default class ReadConfig extends godot.Node {
  static _singleton;

  static get singleton() {
	return ReadConfig._singleton;
  }

  constructor() {
	super();
	if (!ReadConfig._singleton) {
	  ReadConfig._singleton = this;
	}
  }

  // This property is available for other classes
  config = TestJson;
}
