import 'package:flutter/material.dart';

class OnePage extends StatelessWidget {
  const OnePage({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('page one')),
      body: Center(
        child: Text('one page'),
      ),
    );
  }
}
