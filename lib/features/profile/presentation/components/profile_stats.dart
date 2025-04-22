import 'package:flutter/material.dart';

class ProfileStats extends StatelessWidget {
  final int postCount;
  final int followerCount;
  final int followingCount;
  final VoidCallback? onPostsTap;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;

  const ProfileStats({
    super.key,
    required this.postCount,
    required this.followerCount,
    required this.followingCount,
    this.onPostsTap,
    this.onFollowersTap,
    this.onFollowingTap,
  });

  @override
  Widget build(BuildContext context) {
    // Стиль текста для чисел
    var textStyleForCount = TextStyle(
      fontSize: 17,
      color: Theme.of(context).colorScheme.inversePrimary,
    );

    // Стиль текста для подписей
    var textStyleForText = TextStyle(
      fontSize: 13,
      color: Theme.of(context).colorScheme.primary,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Раздел "записи"
        GestureDetector(
          onTap: onPostsTap,
          child: SizedBox(
            width: 100,
            child: Column(
              children: [
                Text(postCount.toString(), style: textStyleForCount),
                Text('Записи', style: textStyleForText),
              ],
            ),
          ),
        ),
        // Раздел "подписчики"
        GestureDetector(
          onTap: onFollowersTap,
          child: SizedBox(
            width: 100,
            child: Column(
              children: [
                Text(followerCount.toString(), style: textStyleForCount),
                Text('Подписчики', style: textStyleForText),
              ],
            ),
          ),
        ),
        // Раздел "подписки"
        GestureDetector(
          onTap: onFollowingTap,
          child: SizedBox(
            width: 100,
            child: Column(
              children: [
                Text(followingCount.toString(), style: textStyleForCount),
                Text('Подписки', style: textStyleForText),
              ],
            ),
          ),
        ),
      ],
    );
  }
}