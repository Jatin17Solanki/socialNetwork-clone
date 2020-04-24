import 'package:flutter/material.dart';


//isApptitle is a named parameter with default value false, similarly titleText

//its not necessary to pass all the named parameters

//if default value is assigned to a parameter then on function call,
//if the parameter isnt assigned any avlue then the default value is used

AppBar header(context, { bool isAppTitle = false, String titleText, 
  bool removeBackButton = false}) {   
  return AppBar(
    automaticallyImplyLeading: removeBackButton ? false : true,
    centerTitle: true,
    title: Text(
      isAppTitle ? 'FlutterShare' : titleText,
    style: TextStyle(
      color: Colors.white,
      fontFamily: isAppTitle ? 'Signatra' : '', //if false then default font is used
      fontSize: isAppTitle ? 50.0 : 22.0,
      ),
    overflow: TextOverflow.ellipsis,
    ),
    backgroundColor: Theme.of(context).accentColor,
  );
}
