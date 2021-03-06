import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html/style.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:global_configuration/global_configuration.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:html/parser.dart';

import '../../generated/l10n.dart';
import '../elements/CircularLoadingWidget.dart';
import '../models/order.dart';
import '../models/product_order.dart';
import '../repository/settings_repository.dart';
import 'app_config.dart' as config;
import 'custom_trace.dart';

class Helper {
  BuildContext context;
  DateTime currentBackPressTime;

  Helper.of(BuildContext _context) {
    this.context = _context;
  }

  // for mapping data retrieved form json array
  static getData(Map<String, dynamic> data) {
    return data['data'] ?? [];
  }

  static int getIntData(Map<String, dynamic> data) {
    return (data['data'] as int) ?? 0;
  }

  static bool getBoolData(Map<String, dynamic> data) {
    return (data['data'] as bool) ?? false;
  }

  static getObjectData(Map<String, dynamic> data) {
    return data['data'] ?? new Map<String, dynamic>();
  }

  static Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png)).buffer.asUint8List();
  }

  static Future<Marker> getMarker(Map<String, dynamic> res) async {
    final Uint8List markerIcon = await getBytesFromAsset('assets/img/marker.png', 120);
    final Marker marker = Marker(
        markerId: MarkerId(res['id']),
        icon: BitmapDescriptor.fromBytes(markerIcon),
//        onTap: () {
//          //print(res.name);
//        },
        anchor: Offset(0.5, 0.5),
        infoWindow: InfoWindow(
            title: res['name'],
            snippet: getDistance(res['distance'].toDouble(), setting.value.distanceUnit),
            onTap: () {
              print(CustomTrace(StackTrace.current, message: 'Info Window'));
            }),
        position: LatLng(double.parse(res['latitude']), double.parse(res['longitude'])));

    return marker;
  }

  static Future<Marker> getOrderMarker(Map<String, dynamic> res) async {
    final Uint8List markerIcon = await getBytesFromAsset('assets/img/marker.png', 120);
    final Marker marker = Marker(
        markerId: MarkerId(res['id']),
        icon: BitmapDescriptor.fromBytes(markerIcon),
//        onTap: () {
//          //print(res.name);
//        },
        anchor: Offset(0.5, 0.5),
        infoWindow: InfoWindow(
            title: res['address'],
            snippet: '',
            onTap: () {
              print('infowi tap');
            }),
        position: LatLng(res['latitude'], res['longitude']));

    return marker;
  }

  static Future<Marker> getMyPositionMarker(double latitude, double longitude) async {
    final Uint8List markerIcon = await getBytesFromAsset('assets/img/my_marker.png', 120);
    final Marker marker = Marker(
        markerId: MarkerId(Random().nextInt(100).toString()),
        icon: BitmapDescriptor.fromBytes(markerIcon),
        anchor: Offset(0.5, 0.5),
        position: LatLng(latitude, longitude));

    return marker;
  }

  static List<Icon> getStarsList(double rate, {double size = 18}) {
    var list = <Icon>[];
    list = List.generate(rate.floor(), (index) {
      return Icon(Icons.star, size: size, color: Color(0xFFFFB24D));
    });
    if (rate - rate.floor() > 0) {
      list.add(Icon(Icons.star_half, size: size, color: Color(0xFFFFB24D)));
    }
    list.addAll(List.generate(5 - rate.floor() - (rate - rate.floor()).ceil(), (index) {
      return Icon(Icons.star_border, size: size, color: Color(0xFFFFB24D));
    }));
    return list;
  }

  static Widget getPrice(double myPrice, BuildContext context, {TextStyle style}) {
    if (style != null) {
      style = style.merge(TextStyle(fontSize: style.fontSize + 2));
    }
    try {
      if (myPrice == 0) {
        return Text('-', style: style ?? Theme.of(context).textTheme.subtitle1);
      }
      return RichText(
        softWrap: false,
        overflow: TextOverflow.fade,
        maxLines: 1,
        text: setting.value?.currencyRight != null && setting.value?.currencyRight == false
            ? TextSpan(
                text: setting.value?.defaultCurrency,
                style: style ?? Theme.of(context).textTheme.subtitle1,
                children: <TextSpan>[
                  TextSpan(text: myPrice.toStringAsFixed(setting.value?.currencyDecimalDigits) ?? '', style: style ?? Theme.of(context).textTheme.subtitle1),
                ],
              )
            : TextSpan(
                text: myPrice.toStringAsFixed(setting.value?.currencyDecimalDigits) ?? '',
                style: style ?? Theme.of(context).textTheme.subtitle1,
                children: <TextSpan>[
                  TextSpan(
                      text: setting.value?.defaultCurrency,
                      style: TextStyle(
                          fontWeight: FontWeight.w400, fontSize: style != null ? style.fontSize - 4 : Theme.of(context).textTheme.subtitle1.fontSize - 4)),
                ],
              ),
      );
    } catch (e) {
      return Text('');
    }
  }

  static double getTotalOrderPrice(ProductOrder productOrder) {
    double total = productOrder.price;
    productOrder.options.forEach((option) {
      total += option.price != null ? option.price : 0;
    });
    total *= productOrder.quantity;
    return total;
  }

  static double getOrderPrice(ProductOrder productOrder) {
    double total = productOrder.price;
    productOrder.options.forEach((option) {
      total += option.price != null ? option.price : 0;
    });
    return total;
  }

  static double getTaxOrder(Order order) {
    double total = 0;
    order.productOrders.forEach((productOrder) {
      total += getTotalOrderPrice(productOrder);
    });
    return order.tax * total / 100;
  }

  static double getTotalOrdersPrice(Order order) {
    double total = 0;
    order.productOrders.forEach((productOrder) {
      total += getTotalOrderPrice(productOrder);
    });
    total += order.deliveryFee;
    total += order.tax * total / 100;
    return total;
  }

  static double getSubTotalOrdersPrice(Order order) {
    double total = 0;
    order.productOrders.forEach((productOrder) {
      total += getTotalOrderPrice(productOrder);
    });
    return total;
  }

  static String getDistance(double distance, String unit) {
    String _unit = setting.value.distanceUnit;
    if (_unit == 'km') {
      distance *= 1.60934;
    }
    return distance != null ? distance.toStringAsFixed(2) + " " + unit : "";
  }

  static String skipHtml(String htmlString) {
    try {
      var document = parse(htmlString);
      String parsedString = parse(document.body.text).documentElement.text;
      return parsedString;
    } catch (e) {
      return '';
    }
  }

  static Html applyHtml(context, String html, {TextStyle style}) {
    return Html(
      data: html ?? '',
      style: {
        "*": Style(
          padding: EdgeInsets.all(0),
          margin: EdgeInsets.all(0),
          color: Theme.of(context).hintColor,
          fontSize: FontSize(16.0),
          display: Display.INLINE_BLOCK,
          width: config.App(context).appWidth(100),
        ),
        "h4,h5,h6": Style(
          fontSize: FontSize(18.0),
        ),
        "h1,h2,h3": Style(
          fontSize: FontSize.xLarge,
        ),
        "br": Style(
          height: 0,
        ),
        "p": Style(
          fontSize: FontSize(16.0),
        )
      },
    );
  }

  static OverlayEntry overlayLoader(context) {
    OverlayEntry loader = OverlayEntry(builder: (context) {
      final size = MediaQuery.of(context).size;
      return Positioned(
        height: size.height,
        width: size.width,
        top: 0,
        left: 0,
        child: Material(
          color: Theme.of(context).primaryColor.withOpacity(0.85),
          child: CircularLoadingWidget(height: 200),
        ),
      );
    });
    return loader;
  }

  static hideLoader(OverlayEntry loader) {
    Timer(Duration(milliseconds: 500), () {
      try {
        loader?.remove();
      } catch (e) {}
    });
  }

  static String limitString(String text, {int limit = 24, String hiddenText = "..."}) {
    return text.substring(0, min<int>(limit, text.length)) + (text.length > limit ? hiddenText : '');
  }

  static String getCreditCardNumber(String number) {
    String result = '';
    if (number != null && number.isNotEmpty && number.length == 16) {
      result = number.substring(0, 4);
      result += ' ' + number.substring(4, 8);
      result += ' ' + number.substring(8, 12);
      result += ' ' + number.substring(12, 16);
    }
    return result;
  }

  static Uri getUri(String path) {
    String _path = Uri.parse(GlobalConfiguration().getString('base_url')).path;
    if (!_path.endsWith('/')) {
      _path += '/';
    }
    Uri uri = Uri(
        scheme: Uri.parse(GlobalConfiguration().getString('base_url')).scheme,
        host: Uri.parse(GlobalConfiguration().getString('base_url')).host,
        port: Uri.parse(GlobalConfiguration().getString('base_url')).port,
        path: _path + path);
    return uri;
  }

  Future<bool> onWillPop() {
    DateTime now = DateTime.now();
    if (currentBackPressTime == null || now.difference(currentBackPressTime) > Duration(seconds: 2)) {
      currentBackPressTime = now;
      Fluttertoast.showToast(msg: S.of(context).tapBackAgainToLeave);
      return Future.value(false);
    }
    SystemChannels.platform.invokeMethod('SystemNavigator.pop');
    return Future.value(true);
  }

  String trans(String text) {
    switch (text) {
      case "App\\Notifications\\StatusChangedOrder":
        return S.of(context).order_satatus_changed;
      case "App\\Notifications\\NewOrder":
        return S.of(context).new_order_from_costumer;
      case "App\\Notifications\\AssignedOrder":
        return S.of(context).your_have_an_order_assigned_to_you;
      case "km":
        return S.of(context).km;
      case "mi":
        return S.of(context).mi;
      default:
        return "";
    }
  }
}
