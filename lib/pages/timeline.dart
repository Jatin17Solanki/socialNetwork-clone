import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttershare/pages/search.dart';
import 'package:fluttershare/widgets/header.dart';
import 'package:fluttershare/models/user.dart';
import 'package:fluttershare/widgets/progress.dart';
import 'home.dart';
import 'package:fluttershare/widgets/post.dart';

final CollectionReference usersRef = Firestore.instance.collection('users');


class Timeline extends StatefulWidget {

  final User currentUser;
  Timeline({this.currentUser});

  @override
  _TimelineState createState() => _TimelineState();
}

class _TimelineState extends State<Timeline> {
  List<Post> posts;
  List<String> followingList = [];
  
  @override
  void initState() {
    super.initState();
    getTimeline();
    getFollowing();
  }

  getTimeline() async {

    QuerySnapshot snapshot = await timelineRef
      .document(widget.currentUser.id)
      .collection('timelinePosts')
      .orderBy('timestamp', descending: true)
      .getDocuments();

    List<Post> posts = snapshot.documents.map((doc) => Post.fromDocument(doc)).toList();
    setState(() {
      this.posts = posts;
    });
  }

  getFollowing() async {

    QuerySnapshot snapshot = await followingRef
      .document(currentUser.id)
      .collection('userFollowing')
      .getDocuments();

    //TRY IF THIS ALSO WORKS
    // setState(() {
    //   snapshot.documents.forEach((doc) { 
    //     if(doc.exists) {
    //       followingList.add(doc.documentID);
    //     }
    //   });
    // });

    setState(() {
      followingList = snapshot.documents.map((doc) => doc.documentID).toList();
    });
  }

  buildTimeline() {
    if( posts == null) {
      return circularProgress();
    } else if (posts.isEmpty) {
      return buildUsersToFollow();
    } else {
      return ListView(children: posts);
    }
  }

  buildUsersToFollow() {
    return StreamBuilder(
      stream: usersRef.orderBy('timestamp', descending: true).limit(30).snapshots(),
      builder: (context, snapshot) {
        if(!snapshot.hasData) {
          return circularProgress();
        } 
        List<UserResult> userResults = [];
        snapshot.data.documents.forEach((doc) {

          User user = User.fromDocument(doc);
          final bool isAuthUser = (currentUser.id == user.id); 
          final bool isFollowingUser = followingList.contains(user.id);

          //remove AuthUser(ie currentUser) from recommendation list
          if(isAuthUser) {
            return ;
          } else if (isFollowingUser) { //remove user from the list if he is already being followed
            return ;
          } else {
            userResults.add(UserResult(user));
          } 
        });

        return Container(
          color: Theme.of(context).accentColor.withOpacity(0.2),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_add,
                      color: Colors.black,
                      size: 30.0,
                    ),
                    SizedBox(width: 8.0),
                    Text(
                      'Users to follow',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 25.0
                      ),
                    ),
                  ],
                ),
              ),
              Column(children: userResults),
            ],
          ),
        );

      }
    );
  }

  @override
  Widget build(context) {
    return Scaffold(
      appBar: header(context, isAppTitle: true),
      body: RefreshIndicator(
        onRefresh: () => getTimeline(),
        child: buildTimeline(),
      )
    );
  }
}
