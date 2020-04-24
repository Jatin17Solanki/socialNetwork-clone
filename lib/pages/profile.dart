import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttershare/pages/edit_profile.dart';
import 'package:fluttershare/widgets/header.dart';
import 'package:fluttershare/widgets/progress.dart';
import 'package:fluttershare/models/user.dart';
import 'package:fluttershare/pages/home.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttershare/widgets/post.dart';
import 'package:fluttershare/widgets/post_tile.dart';
import 'package:flutter_svg/flutter_svg.dart';

class Profile extends StatefulWidget {
  final String profileId;
  Profile({this.profileId});

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  //currentUser - imported from home.dart
  //assign currentUser.id if currentUser is not null
  final String currentUserId = currentUser?.id; 
  bool isLoading = false;
  int postCount = 0;
  List<Post> posts = [];
  String postOrientation = 'grid';
  bool isFollowing = false;
  int followerCount = 0;
  int followingCount = 0;
  
  @override
  void initState() { 
    super.initState();
    getProfilePosts();
    getFollowers();
    getFollowing();
    checkIfFollowing();
  }

  checkIfFollowing() async {
    DocumentSnapshot doc = await followersRef
      .document(widget.profileId)
      .collection('userFollowers')
      .document(currentUserId)
      .get();

    setState(() {
      isFollowing = doc.exists;
    });
  }

  getFollowers() async {
    QuerySnapshot snapshot = await followersRef
      .document(widget.profileId)
      .collection('userFollowers')
      .getDocuments();

    setState(() {
      followerCount = snapshot.documents.length;
    });
  }

  getFollowing() async {
    QuerySnapshot snapshot = await followingRef
      .document(widget.profileId)
      .collection('userFollowing')
      .getDocuments();

    setState(() {
      followingCount = snapshot.documents.length;
    });
  }

  getProfilePosts()  async{

    setState(() {
      isLoading = true;
    });
    
    QuerySnapshot  snapshot = await postsRef
      .document(widget.profileId)
      .collection('userPosts')
      .orderBy('timestamp', descending: true)
      .getDocuments();

    setState(() {
      isLoading = false;
      postCount = snapshot.documents.length;
      posts = snapshot.documents.map((doc) => Post.fromDocument(doc)).toList();
    });
  }

  Column buildCountColumn(String label, int count) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 22.0,
            fontWeight: FontWeight.bold
          ),
        ),
        Container(
          padding: EdgeInsets.only(top: 4.0),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w400,
              fontSize: 15.0
            ),
          ),
        )
      ],
    );
  }
  editProfile() {
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => EditProfile(currentUserId : currentUserId)));
  }

  buildButton({String text,Function function}) {
    return Container(
      padding: EdgeInsets.only(top: 2.0),
      child: FlatButton(
        onPressed: function, 
        child: Container(
          width: 215.0,
          height: 27.0,
          child: Text(
            text,
            style: TextStyle(
              color: isFollowing ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold
            ),
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isFollowing ? Colors.white : Colors.blue,
            border: Border.all(
              color: isFollowing ? Colors.grey : Colors.blue,
            ),
            borderRadius: BorderRadius.circular(5.0)
          ),
        )
      ),
    );
  }

  buildProfileButton() {
    //if viewing your own profile- show edit profile button
    bool isProfileOwner = currentUserId == widget.profileId;
    if(isProfileOwner) {
      return buildButton(
        text: "Edit Profile",
        function: editProfile
      );
    } else if(isFollowing) {
      return buildButton(
        text: 'Unfollow', 
        function: handleUnfollowUser
      );
    } else if(!isFollowing) {
      return buildButton(
        text: 'Follow',
        function: handleFollowUser
      );
    }
  }

  handleUnfollowUser() {

    setState(() {
      isFollowing = false;
    });

    //remove follower
    followersRef
      .document(widget.profileId)
      .collection('userFollowers')
      .document(currentUserId)
      .get()
      .then((doc) {
        if(doc.exists)
          doc.reference.delete(); 
      });

    //remove following
    followingRef
      .document(currentUserId)
      .collection('userFollowing')
      .document(widget.profileId)
      .get()
      .then((doc) {
        if(doc.exists)
          doc.reference.delete(); 
      });

    //delete activity feed item for them
    activityFeedRef
      .document(widget.profileId)
      .collection('feedItems')
      .document(currentUserId)
      .get()
      .then((doc) {
        if(doc.exists)
          doc.reference.delete(); 
      });

  }

  handleFollowUser() {

    setState(() {
      isFollowing = true;
    });

    //Make auth user follower of THAT user (update their followers collection)
    followersRef
      .document(widget.profileId)
      .collection('userFollowers')
      .document(currentUserId)
      .setData({});

    //put THAT user on YOUR following collection(update your following collection)  
    followingRef
      .document(currentUserId)
      .collection('userFollowing')
      .document(widget.profileId)
      .setData({});

    //add activity feed item for THAT user to notify about new follower(which is us)
    activityFeedRef
      .document(widget.profileId)
      .collection('feedItems')
      .document(currentUserId)
      .setData({
        'type': 'follow',
        'ownerId': widget.profileId,
        'username': currentUser.username,
        'userId': currentUserId,
        'userProfileImg': currentUser.photoUrl,
        'timestamp': timestamp
      });
  }

  buildProfileHeader() {
    return FutureBuilder(
      future: usersRef.document(widget.profileId).get(),
      builder: (context, snapshot) {
        if(!snapshot.hasData)
          return circularProgress();
        
        User user = User.fromDocument(snapshot.data);
        return Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 40.0,
                    backgroundImage: CachedNetworkImageProvider(user.photoUrl),
                    backgroundColor: Colors.grey,
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: <Widget>[
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: <Widget>[
                            buildCountColumn('posts',postCount),
                            buildCountColumn('followers',followerCount),
                            buildCountColumn('following',followingCount),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: <Widget>[
                            buildProfileButton(),
                          ],
                        )
                      ],
                    ),
                  ),
                ],
              ),
              Container(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  user.username,
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold
                  ),
                ),
              ),
              Container(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.only(top: 4.0),
                child: Text(
                  user.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold
                  ),
                ),
              ),
              Container(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.only(top: 2.0),
                child: Text(
                  user.bio,
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  buildProfilePosts() {
    if(isLoading)
      return circularProgress();
    else if (posts.isEmpty) {
      return Container(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  SvgPicture.asset('assets/images/no_content.svg',height: 200,),
                  Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'No Posts',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 35,
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  ),
                ],
              ),
            );
    }
    else if ( postOrientation == 'grid') {
      List<GridTile> gridTiles = [];
      posts.forEach((post) {
        gridTiles.add(
          GridTile( child: PostTile(post),)
        );
      });
      return GridView.count(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        mainAxisSpacing: 1.5,
        crossAxisSpacing: 1.5,
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        children: gridTiles,
      );
    }
    else if ( postOrientation == 'list') {
      return Column(
        children: posts,
      );
    }

  }

  buildTogglePostOrientation() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        IconButton(
          icon: Icon(Icons.grid_on),
          color: postOrientation == 'grid' ? Theme.of(context).primaryColor : Colors.grey, 
          onPressed: () {
            setState(() {
              postOrientation = 'grid';
            });
          }
        ),
        IconButton(
          icon: Icon(Icons.list),
          color: postOrientation == 'list' ? Theme.of(context).primaryColor : Colors.grey, 
          onPressed: () {
            setState(() {
              postOrientation = 'list';
            });
          }
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: header(context, titleText: 'Profile'),
      body: ListView(
        children: <Widget>[
          buildProfileHeader(),
          Divider(),
          buildTogglePostOrientation(),
          Divider(height: 0.0,),
          buildProfilePosts(),
        ],
      ),
    );
  }
}
