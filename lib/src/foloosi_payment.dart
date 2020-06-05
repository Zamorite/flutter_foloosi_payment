import 'dart:convert';
import 'dart:io';

import 'package:foloosi_payment/src/elements/circular_loader.dart';
import 'package:foloosi_payment/src/helpers/custom_trace.dart';
import 'package:foloosi_payment/src/models/foloosi.dart';
import 'package:foloosi_payment/src/models/route_argument.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';
import 'package:http/http.dart' as http;

// ignore: must_be_immutable
class FoloosiPayment extends StatefulWidget {
  final String headerText;
  final String successRoute;
  var successRouteParam;
  final String loaderText;
  final String merchantKey;
  final String secretKey;
  String referenceToken;
  final String redirectUrl;
  final double transactionAmount;
  final String currency;
  final String customerName;
  final String customerEmail;
  final String customerMobile;
  final String customerAddress;
  final String customerCity;
  final bool debugMode;

  FoloosiPayment({
    Key key,
    this.headerText,
    this.successRoute,
    this.successRouteParam,
    this.loaderText: "",
    this.merchantKey,
    this.secretKey,
    this.referenceToken: "",
    this.redirectUrl: "",
    this.transactionAmount: 0,
    this.currency: "",
    this.customerName: "",
    this.customerEmail: "",
    this.customerMobile: "",
    this.customerAddress: "",
    this.customerCity: "",
    this.debugMode: false,
  }) : super(key: key);

  @override
  _FoloosiPaymentState createState() => _FoloosiPaymentState();
}

class _FoloosiPaymentState extends State<FoloosiPayment> {
  final flutterWebViewPlugin = FlutterWebviewPlugin();

  bool processing = true;

  @override
  void initState() {
    super.initState();
    if (!widget.debugMode) {
      // TODO disable log if debug mode is false
    }
    if (widget.referenceToken == "") {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        getReferenceToken();
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    flutterWebViewPlugin.close();
  }

  void getReferenceToken() async {
    Foloosi foloosi = Foloosi();
    foloosi.transaction_amount = widget.transactionAmount;
    foloosi.currency = widget.currency;
    foloosi.customer_name = widget.customerName;
    foloosi.customer_email = widget.customerEmail;
    foloosi.customer_mobile = widget.customerMobile;

    final String url = "https://foloosi.com/api/v1/api/initialize-setup";
    final client = new http.Client();
    Map<String, dynamic> decodedJSON = {};

    print(CustomTrace(StackTrace.current,
        message: json.encode(foloosi.toMap()).toString()));

    final response = await client.post(
      url,
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
        'merchant_key': widget.merchantKey,
        'secret_key': widget.secretKey
      },
      body: json.encode(foloosi.toMap()),
    );
    try {
      if (response.statusCode == 200) {
        decodedJSON =
        json.decode(response.body)['data'] as Map<String, dynamic>;

        widget.referenceToken = decodedJSON['reference_token'];
        setState(() {
          processing = false;
        });
        print(CustomTrace(StackTrace.current,
            message: decodedJSON['reference_token']));
      } else {
        print(
            CustomTrace(StackTrace.current, message: response.body.toString()));
      }
    } on FormatException catch (e) {
      print(CustomTrace(StackTrace.current, message: e.toString()));
    }
  }

  JavascriptChannel jsChannels(BuildContext context) {
    return JavascriptChannel(
        name: 'Print',
        onMessageReceived: (JavascriptMessage message) {
          print(message.message);
          if (message.message == "success") {
            flutterWebViewPlugin.close();
            Navigator.of(context).pushNamed(widget.successRoute,
                arguments: RouteArgument(param: widget.successRouteParam));
          } else if (message.message == "paymentCancelled") {
            flutterWebViewPlugin.close();
            Navigator.pop(context);
          } else {
            flutterWebViewPlugin.close();
            Navigator.pop(context);
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    String url = new Uri.dataFromString("""
    <!DOCTYPE html>
          <html lang="en">
                <head>
                  <meta charset="UTF-8" />
                  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
                  <title>Foloosi</title>
                  <style>
                    .foloosi_lightBackWrap {
                      background: white !important;
                    }
                    ::-webkit-scrollbar {
                        width: 5px;
                    }
                     
                    /* Track */
                    ::-webkit-scrollbar-track {
                        -webkit-box-shadow: inset 0 0 6px rgba(0,0,0,0); 
                        -webkit-border-radius: 10px;
                        border-radius: 10px;
                    }
                     
                    /* Handle */
                    ::-webkit-scrollbar-thumb {
                        -webkit-border-radius: 10px;
                        border-radius: 10px;
                        background: transparent; 
                        -webkit-box-shadow: inset 0 0 6px rgba(0,0,0,0.5); 
                    }
                    ::-webkit-scrollbar-thumb:window-inactive {
                      background: transparent; 
                    }
                  </style>
                </head>
                <body>
                  <script
                    type="text/javascript"
                    src="https://www.foloosi.com/js/foloosipay.v2.js"
                  ></script>
                  <script type="text/javascript">
                    var options = {
                      reference_token:
                        '${widget.referenceToken}', 
                      merchant_key:
                        '${widget.merchantKey}',
                    }
                    var fp1 = new Foloosipay(options)
                    document.addEventListener(
                      'DOMContentLoaded',
                      function () {
                        fp1.open()
                      },
                      false
                    )
                    var closeButton = document.getElementById('foloosi_close')
                    closeButton.addEventListener('click', function (event) {
                      Print.postMessage('paymentCancelled')
                    })
                    foloosiHandler(response, function (e) {
                      if (e.data.status == 'success') {
                        Print.postMessage(e.data.status)
                        Print.postMessage(e.data.data)
                      }
                      if (e.data.status == 'error') {
                        Print.postMessage(e.data.status)
                        Print.postMessage(e.data.data)
                      }
                    })
                  </script>
                </body>
          </html>""", mimeType: 'text/html').toString();

    return Scaffold(
      key: widget.key,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.headerText,
          style: Theme.of(context)
              .textTheme
              .headline6
              .merge(TextStyle(letterSpacing: 1.3)),
        ),
      ),
      body: Stack(
        children: <Widget>[
          processing
              ? AnimatedOpacity(
            opacity: processing ? 1.0 : 0.0,
            duration: Duration(milliseconds: 5),
            child: Container(
              color: Colors.white,
              child: Center(
                child: CircularLoader(height: 200),
              ),
            ),
          )
              : WebviewScaffold(
              url: url,
              withJavascript: true,
              javascriptChannels: <JavascriptChannel>[
                jsChannels(context),
              ].toSet(),
              mediaPlaybackRequiresUserGesture: false,
              withZoom: true,
              withLocalStorage: true,
              hidden: true,
              initialChild: Container(
                color: Colors.white,
                child: Center(
                  child: CircularLoader(height: 200),
                ),
              ))
        ],
      ),
    );
  }
}