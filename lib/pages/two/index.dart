import 'package:flutter/material.dart';

class TwoPage extends StatelessWidget {
  const TwoPage({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('page Two')),
      body: Center(
        child: Text('Two'),
      ),
    );
  }
}
