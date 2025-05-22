import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socail_media_app/features/post/presentation/components/post_tile.dart';
import 'package:socail_media_app/features/post/presentation/cubits/post_cubit.dart';
import 'package:socail_media_app/features/post/presentation/cubits/post_states.dart';
import 'package:socail_media_app/features/profile/presentation/components/bio_box.dart';
import 'package:socail_media_app/features/profile/presentation/components/follow_button.dart';
import 'package:socail_media_app/features/profile/presentation/components/profile_stats.dart';
import 'package:socail_media_app/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:socail_media_app/features/profile/presentation/pages/follower_page.dart';
import 'package:socail_media_app/responsive/constrained_scaffold.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/cubits/auth_cubit.dart';
import '../cubit/profile_states.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  final String uid;

  const ProfilePage({super.key, required this.uid});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // cubits
  late final authCubit = context.read<AuthCubit>();
  late final profileCubit = context.read<ProfileCubit>();

  // current user
  late AppUser? currentUser = authCubit.currentUser;

  // posts
  int postCount = 0;

  @override
  void initState() {
    super.initState();

    profileCubit.fetchUserProfile(widget.uid);
  }

  void followButtonPressed() {
    final profileState = profileCubit.state;
    if (profileState is! ProfileLoaded) {
      return;
    }

    final profileUser = profileState.profileUser;
    final isFollowing = profileUser.followers.contains(currentUser!.uid);

    // optimize
    setState(() {
      // unfollow
      if (isFollowing) {
        profileUser.followers.remove(currentUser!.uid);
      }

      // follow
      else {
        profileUser.followers.add(currentUser!.uid);
      }
    });

    profileCubit.toggleFollow(currentUser!.uid, widget.uid).catchError((error) {
      // revert update if there's an error
      setState(() {
        // unfollow
        if (isFollowing) {
          profileUser.followers.add(currentUser!.uid);
        }

        // follow
        else {
          profileUser.followers.remove(currentUser!.uid);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isOwnPost = widget.uid == currentUser!.uid;

    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, profileState) {
        if (profileState is ProfileLoaded) {
          final user = profileState.profileUser;

          return ConstrainedScaffold(
            appBar: AppBar(
              title: Text(user.name),
              foregroundColor: Theme.of(context).colorScheme.primary,
              actions: [
                if (isOwnPost)
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditProfilePage(user: user),
                      ),
                    ),
                    icon: const Icon(Icons.settings),
                  ),
              ],
            ),
            body: BlocBuilder<PostCubit, PostState>(
              builder: (context, postState) {
                final userPosts = postState is PostLoaded
                    ? postState.posts
                        .where((post) => post.userId == widget.uid)
                        .toList()
                    : [];

                return ListView(
                  children: [
                    // email
                    Center(
                      child: Text(
                        user.email,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    const SizedBox(height: 25),

                    // profile image
                    CachedNetworkImage(
                      imageUrl: user.profileImageUrl.isNotEmpty
                          ? "${user.profileImageUrl}?t=${DateTime.now().millisecondsSinceEpoch}"
                          : 'https://via.placeholder.com/150',
                      placeholder: (context, url) =>
                          const CircularProgressIndicator(),
                      errorWidget: (context, url, error) => Icon(
                        Icons.person,
                        size: 72,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      imageBuilder: (context, imageProvider) => Container(
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image: imageProvider,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    // profile stats
                    ProfileStats(
                      postCount: userPosts.length,
                      followerCount: user.followers.length,
                      followingCount: user.following.length,
                      onPostsTap: null,
                      onFollowersTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FollowerPage(
                            followers: user.followers,
                            following: user.following,
                            initialTab: 'followers',
                          ),
                        ),
                      ),
                      onFollowingTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FollowerPage(
                            followers: user.followers,
                            following: user.following,
                            initialTab: 'following',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    if (!isOwnPost)
                      FollowButton(
                        onPressed: followButtonPressed,
                        isFollowing: user.followers.contains(currentUser!.uid),
                      ),
                    const SizedBox(height: 25),

                    Padding(
                      padding: const EdgeInsets.only(left: 25.0),
                      child: Row(
                        children: [
                          Text(
                            'Описание',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.primary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    BioBox(text: user.bio),

                    Padding(
                      padding: const EdgeInsets.only(left: 25.0, top: 25),
                      child: Row(
                        children: [
                          Text(
                            'Лента',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.primary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Post list
                    if (postState is PostLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (userPosts.isEmpty)
                      const Center(child: Text('Нет постов..'))
                    else
                      ListView.builder(
                        itemCount: userPosts.length,
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemBuilder: (context, index) {
                          final post = userPosts[index];
                          return PostTile(
                            post: post,
                            onDeletePressed: () =>
                                context.read<PostCubit>().deletePost(post.id),
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          );
        }

        if (profileState is ProfileLoading) {
          return const ConstrainedScaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return const Center(child: Text('Профиль не найден'));
      },
    );
  }
}
