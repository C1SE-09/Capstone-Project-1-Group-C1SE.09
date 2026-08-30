import 'package:adark_frontend/data/notifiers.dart';
import 'package:adark_frontend/presentation/pages/home_page.dart';
import 'package:adark_frontend/presentation/pages/profile_page.dart';
import 'package:adark_frontend/presentation/widgets/navbar_widget.dart';
import 'package:flutter/material.dart';

List<Widget> page = [HomePage(), ProfilePage()];

class WidgetTree extends StatelessWidget {
  const WidgetTree({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Center(child: Text("Home Page"))),
      body: ValueListenableBuilder(
        valueListenable: selectedPageNotifiers,
        builder: (context, value, child) {
          return page.elementAt(value);
        },
      ),
      bottomNavigationBar: NavbarWidget(),
    );
  }
}
