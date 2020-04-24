import 'dart:async';

import 'package:animator/animator.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttershare/pages/activity_feed.dart';
import 'package:fluttershare/pages/comments.dart';
import 'package:fluttershare/pages/home.dart';
import 'package:fluttershare/widgets/progress.dart';
import 'package:fluttershare/models/user.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluttershare/widgets/custom_image.dart';

class Post extends StatefulWidget {

  final String postId;
  final String username;
  final String ownerId;
  final String mediaUrl;
  final String location;
  final dynamic likes;
  final String description;

  Post({
    this.postId,
    this.username,
    this.ownerId,
    this.mediaUrl,
    this.location,
    this.likes,
    this.description,
  });

  factory Post.fromDocument(DocumentSnapshot doc) {
    return Post(
      postId: doc['postId'],
      ownerId: doc['ownerId'],
      username: doc['username'],
      location: doc['location'],
      description: doc['description'],
      mediaUrl: doc['mediaUrl'],
      likes: doc['likes'],
    );
  }

  int getLikeCount(likes) {
    //if no likes return 0
    if(likes == null)
    return 0;

    int count = 0;
    //if the key is explicitly set to true, add a like
    likes.values.forEach((val) {
      if(val == true )
        count+=1;
    });
    return count;
  }

  @override

  _PostState createState() => _PostState(
    postId: this.postId,
    ownerId: this.ownerId,
    username: this.username,
    location: this.location,
    description: this.description,
    mediaUrl: this.mediaUrl,
    likes: this.likes,
    likeCount: getLikeCount(this.likes),
  );
}

class _PostState extends State<Post> {

  final String currentUserId = currentUser?.id;
  bool isLiked;
  bool showHeart = false;

  final String postId;
  final String ownerId;
  final String username;
  final String location;
  final String description;
  final String mediaUrl;
  int likeCount;
  Map likes;

  _PostState({
    this.postId,
    this.ownerId,
    this.username,
    this.location,
    this.description,
    this.mediaUrl,
    this.likes,
    this.likeCount,
  });

  buildPostHeader() {
    return FutureBuilder(
      future: usersRef.document(ownerId).get(),
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if(!snapshot.hasData)
          return circularProgress();

        User user = User.fromDocument(snapshot.data);

        bool isPostOwner = currentUserId == ownerId;

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: CachedNetworkImageProvider(user.photoUrl), 
            backgroundColor: Colors.grey,
          ),
          title: GestureDetector(
            onTap: () => showProfile(context, profileId: user.id ),
            child: Text(
              user.username,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black
              ),
            ),
          ),
          subtitle: Text(location),
          trailing: isPostOwner ? IconButton(
            onPressed: () => handleDeletePost(context),
            icon: Icon(Icons.more_vert),
          ) : Text(''),
        ); 
      },
    );
  }

  //Note:  to delete a post, ownerId and currentUserId must be equal, hence they can be used interchangeably
  deletePost() async {
    //delete the post itself
    postsRef
      .document(ownerId)
      .collection('userPosts')
      .document(postId)
      .get()
      .then((doc) {
        if(doc.exists) {
          doc.reference.delete();
        }
      });

    //delete uploaded image for the post from firebase storage
    storageRef.child('post_$postId.jpg').delete();

    //then delete all activity feed notifications
    QuerySnapshot activityFeedSnapshot = await activityFeedRef
      .document(ownerId)
      .collection('feedItems')
      .where('postId', isEqualTo: postId)
      .getDocuments();

    activityFeedSnapshot.documents.forEach((doc) {
      if(doc.exists) {
        doc.reference.delete();
      }
    });

    //delete all the comments related to this post
    QuerySnapshot commentsSnapshot = await commentsRef
      .document(postId)
      .collection('comments')
      .getDocuments();

    commentsSnapshot.documents.forEach((doc) {
      if(doc.exists) {
        doc.reference.delete();
      }
    });
  }

  handleDeletePost(BuildContext parentContext) {
    return showDialog(
      context: parentContext,
      builder: (context) {
        return SimpleDialog(
          title: Text('Remove this post?'),
          children: [
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                deletePost();
              },
              child: Text('Delete',
                style: TextStyle(
                  color: Colors.red
                )
              ),
            ),
            SimpleDialogOption(
              child: Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            )
          ],
        );
      }
    );
  }

  addLikeToActivityFeed() {
    //add a notification to the postOwner's activity feed only if comment made by 
    // OTHER user (to avoid getting notifications for our own like)
    bool isNotPostOwner = currentUserId != ownerId;
    if(isNotPostOwner) {
      activityFeedRef
        .document(ownerId)
        .collection('feedItems')
        .document(postId)
        .setData({
          'type': 'like',
          'username': currentUser.username,
          'userId': currentUser.id,
          'userProfileImg': currentUser.photoUrl,
          'postId': postId,
          'mediaUrl': mediaUrl,
          'timestamp': timestamp
        });  
    }
  }

  removeLikeFromActivityFeed() {
    bool isNotPostOwner = currentUserId != ownerId;
    if(isNotPostOwner) {
      activityFeedRef
        .document(ownerId)
        .collection('feedItems')
        .document(postId)
        .get().then((doc) {
          if(doc.exists)
            doc.reference.delete();
        });
    }
  }
  //           OR 
  // removeLikeFromActivityFeed() async {
  //   DocumentSnapshot doc =
  //    await activityRef
  //           .document(ownerId)
  //           .collection('feedItems')
  //           .document(postId)
  //           .get();
  //   if(doc.exists) {
  //     doc.reference.delete();
  //   }
  // }

  handleLikePost() {
    bool _isLiked = likes[currentUserId] == true ;

    if(_isLiked) {
      postsRef
        .document(ownerId)
        .collection('userPosts')
        .document(postId)
        .updateData({'likes.$currentUserId' : false});

      removeLikeFromActivityFeed();

      setState(() {
        likeCount -= 1;
        isLiked = false;
        likes[currentUserId] = false;
      });
    } else if (!_isLiked) {
      postsRef
        .document(ownerId)
        .collection('userPosts')
        .document(postId)
        .updateData({'likes.$currentUserId' : true});
      
      addLikeToActivityFeed();

      setState(() {
        likeCount += 1;
        isLiked = true;
        likes[currentUserId] = true;
        showHeart = true;
      });
      Timer(Duration(milliseconds: 500), () { 
        setState(() {
          showHeart = false;
        });
      });
    }
  }

  buildPostImage() {
    return GestureDetector(
      onDoubleTap: handleLikePost,
      child: Container(
        // height: 350,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            cachedNetworkImage(mediaUrl),
            showHeart ? Animator(
              duration: Duration(milliseconds: 300),
              tween: Tween(begin: 0.8, end: 1.4),
              curve: Curves.elasticOut,
              cycles: 0,
              builder: (anim) => Transform.scale(
                scale: anim.value,
                child: Icon(
                  Icons.favorite,
                  size: 80.0,
                  color: Colors.red,
                )
              ),
            ) : Text(''),
          ],
        ),
      ),
    );
  }

  buildPostFooter() {
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Padding(padding: EdgeInsets.only(top: 40,left: 20),),
            GestureDetector(
              onTap: handleLikePost,
              child: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                size: 28,
                color: Colors.pink,
              ),
            ),
            Padding(padding: EdgeInsets.only(right: 20),),
            GestureDetector(
              onTap: () => showComments(
                context,
                mediaUrl: mediaUrl,
                ownerId: ownerId,
                postId: postId
              ),
              child: Icon(
                Icons.chat,
                size: 28,
                color: Colors.blue[900],
              ),
            ),
          ],
        ),
        Row(
          children: <Widget>[
            Container(
              margin: EdgeInsets.only(left: 20.0),
              child: Text(
                '$likeCount likes',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold
                ),
              ),
            )
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              margin: EdgeInsets.only(left: 20.0),
              child: Text(
                username,
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
            Expanded(child: Text(description),)
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    isLiked = ( likes[currentUserId] == true );

    return Column(
      children: <Widget>[
        buildPostHeader(),
        buildPostImage(),
        buildPostFooter()
      ],
    );
  }
}

showComments(BuildContext context, {String postId,String ownerId, String mediaUrl}) {
  Navigator.push(context, MaterialPageRoute(builder: (context) {
    return Comments(
      postId: postId,
      postOwnerId: ownerId,
      postMediaUrl: mediaUrl
    );
  }));

}