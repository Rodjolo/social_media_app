import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socail_media_app/features/auth/domain/entities/app_user.dart';
import 'package:socail_media_app/features/auth/presentation/components/my_text_field.dart';
import 'package:socail_media_app/features/post/domain/enteties/post.dart';
import 'package:socail_media_app/features/post/presentation/cubits/post_cubit.dart';
import 'package:socail_media_app/features/post/presentation/cubits/post_states.dart';
import '../../../auth/presentation/cubits/auth_cubit.dart';

class UploadPostPage extends StatefulWidget {
  const UploadPostPage({super.key});

  @override
  State<UploadPostPage> createState() => _UploadPostPageState();
}

class _UploadPostPageState extends State<UploadPostPage> {
  // mobile image pick
  PlatformFile? imagePickedFile;

  // web image pick
  Uint8List? webImage;

  // text controller
  final textController = TextEditingController();

  AppUser? currentUser;

  @override
  void initState() {
    super.initState();

    getCurrentUser();
  }

  // get current user
  void getCurrentUser() async {
    final authCubit = context.read<AuthCubit>();
    currentUser = authCubit.currentUser;
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

  // create and upload post
  void uploadPost() {
    if (textController.text.isEmpty || currentUser?.name == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Заполните текст и проверьте имя пользователя')));
      return;
    }

    final newPost = Post(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      userId: currentUser!.uid,
      userName: currentUser!.name,
      text: textController.text,
      imageUrl: '',
      timestamp: DateTime.now(),
      likes: [],
      comments: [],
    );

    final postCubit = context.read<PostCubit>();

    // web upload
    if (kIsWeb) {
      postCubit.createPost(newPost, imageBytes: imagePickedFile?.bytes);
    }

    // mobile upload
    else {
      postCubit.createPost(newPost, imagePath: imagePickedFile?.path);
    }
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PostCubit, PostState>(
      builder: (context, state) {
        print(state);
        // loading or uploading ..
        if (state is PostLoading || state is PostUploading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return buildUploadPage();
      },
      listener: (context, state) {
        if (state is PostLoaded) {
          Navigator.pop(context);
        }
        if (state is PostError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
    );
  }

  Widget buildUploadPage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Создать пост'),
        foregroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            onPressed: () {
              if (textController.text.isNotEmpty && imagePickedFile != null) {
                uploadPost();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ошибка, добавьте текст')));
              }
            },
            icon: const Icon(Icons.upload),
          ),
        ],
      ),
      body: Column(
        children: [
          // image preview for web
          if (kIsWeb && webImage != null) Image.memory(webImage!),

          // image preview for mobile
          if (!kIsWeb && imagePickedFile != null)
            Image.file(File(imagePickedFile!.path!)),

          // pick image button
          MaterialButton(
            onPressed: pickImage,
            color: Colors.blue,
            child: const Text('Выбрать Фото'),
          ),

          MyTextField(
              controller: textController,
              hintText: 'Текст',
              obscureText: false),
        ],
      ),
    );
  }
}
