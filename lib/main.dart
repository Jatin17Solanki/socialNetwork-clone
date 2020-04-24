// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttershare/pages/home.dart';


void main() {
  // Firestore.instance.settings(timestampsInSnapshotsEnabled: true)
  // .then((_) {
  //   print('Timestamp enabled in snapshots\n');
  // },onError: (_) {
  //   print('Error enabling timestamps in snapshots\n');
  // });
  runApp(MyApp());
}


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        accentColor: Colors.black87,
      ),
      title: 'FlutterShare',
      debugShowCheckedModeBanner: false,
      home: Home(),
    );
  }
}
