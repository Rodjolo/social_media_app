import 'dart:io';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socail_media_app/features/auth/presentation/components/my_text_field.dart';
import 'package:socail_media_app/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:socail_media_app/features/profile/presentation/cubit/profile_states.dart';

import '../../domain/entities/profile_user.dart';

class EditProfilePage extends StatefulWidget {
  final ProfileUser user;

  const EditProfilePage({
    super.key,
    required this.user,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  // mobile image picker
  PlatformFile? imagePickedFile;

  // web image picker
  Uint8List? webImage;

  // bio text controller
  final bioTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    bioTextController.text =
        widget.user.bio;
  }

  // pick image
  Future<void> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: kIsWeb,
    );
    if (result != null) {
      setState(() {
        imagePickedFile = result.files.first;
        if (kIsWeb) {
          webImage = imagePickedFile!.bytes;
        }
      });
    }
  }

  // update profile button pressed
  void updateProfile() async {
    final profileCubit = context.read<ProfileCubit>();

    // prepare images
    final String uid = widget.user.uid;
    final String? newBio = bioTextController.text.trim().isNotEmpty
        ? bioTextController.text.trim()
        : null;
    final imageMobilePath = kIsWeb ? null : imagePickedFile?.path;
    final imageWebBytes = kIsWeb ? imagePickedFile?.bytes : null;

    if (imagePickedFile != null || newBio != null) {
      profileCubit.updateProfile(
        uid: uid,
        newBio: bioTextController.text,
        imageMobilePath: imageMobilePath,
        imageWebBytes: imageWebBytes,
      );
    }

    // nothing to update
    else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    //SCAFFOLD
    return BlocConsumer<ProfileCubit, ProfileState>(
      builder: (context, state) {
        // profile loading..
        if (state is ProfileLoading) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(
                    height: 10,
                  ),
                  Text('Загрузка...'),
                ],
              ),
            ),
          );
        }

        // profile error
        else {
          // edit form
          return buildEditPage();
        }
      },
      listener: (context, state) {
        if (state is ProfileLoaded) {
          setState(() {
            imagePickedFile = null;
            webImage = null;
          });
          Navigator.pop(context);
        }
        if (state is ProfileError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
    );
  }

  Widget buildEditPage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Изменить профиль'),
        foregroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          // save button
          IconButton(onPressed: updateProfile, icon: const Icon(Icons.upload))
        ],
      ),
      body: Column(
        children: [
          // profile picture
          Center(
            child: Container(
              height: 200,
              width: 200,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.hardEdge,
              child:
                  // for mobile
                  (imagePickedFile != null)
                      ? Image.file(
                          File(
                            imagePickedFile!.path!,
                          ),
                          fit: BoxFit.cover,
                        )
                      :
                      // for web
                      (kIsWeb && webImage != null)
                          ? Image.memory(
                              webImage!,
                              fit: BoxFit.cover,
                            )
                          :
                          // no image
                          CachedNetworkImage(
                              imageUrl:
                                  "${widget.user.profileImageUrl}?t=${DateTime.now().millisecondsSinceEpoch}",
                              fit: BoxFit.cover,

                              // loading..
                              placeholder: (context, url) =>
                                  const CircularProgressIndicator(),

                              // error
                              errorWidget: (context, url, error) => Icon(
                                Icons.person,
                                size: 72,
                                color: Theme.of(context).colorScheme.primary,
                              ),

                              // loaded
                              imageBuilder: (context, imageProvider) => Image(
                                image: imageProvider,
                                fit: BoxFit.cover,
                              ),
                            ),
            ),
          ),

          const SizedBox(height: 25),

          Center(
            child: MaterialButton(
              onPressed: pickImage,
              color: Colors.blue,
              child: const Text('Выбрать Фото'),
            ),
          ),

          // bio
          const Text('Описание'),

          const SizedBox(
            height: 10,
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25.0),
            child: MyTextField(
              controller: bioTextController,
              hintText: widget.user.bio,
              obscureText: false,
            ),
          ),
        ],
      ),
    );
  }
}
