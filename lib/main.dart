import 'package:contributors_wall/main_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Contributors showcase',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.from(colorScheme: ColorScheme.light()),
        home: ContributorsWall(),
      ),
    );
  }
}
