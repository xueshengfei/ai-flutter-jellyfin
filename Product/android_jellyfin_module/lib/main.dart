import 'package:flutter/material.dart';
import 'package:flutter_boost/flutter_boost.dart';

import 'boost_app.dart';

void main() {
  CustomFlutterBinding();
  runApp(const BoostModuleApp());
}

/// FlutterBoost 自定义 Binding
class CustomFlutterBinding extends WidgetsFlutterBinding
    with BoostFlutterBinding {}
