import 'package:flutter/material.dart';

class FollowButton extends StatelessWidget {
  final void Function()? onPressed;
  final bool isFollowing;

  const FollowButton({
    super.key,
    required this.onPressed,
    required this.isFollowing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      // padding outside
      padding: const EdgeInsets.symmetric(horizontal: 25.0),

      // button
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: MaterialButton(
          onPressed: onPressed,

          padding: const EdgeInsets.all(25.0),

          // color
          color:
              isFollowing ? Theme.of(context).colorScheme.primary : Colors.blue,

          // text
          child: Text(
            isFollowing ? 'Отписаться' : 'Подписаться',
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
