import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../components/my_button.dart';
import '../components/my_text_field.dart';
import '../cubits/auth_cubit.dart';

class RegisterPage extends StatefulWidget {
  final void Function()? togglePages;
  const RegisterPage({super.key, required this.togglePages});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final pwController = TextEditingController();
  final confirmPwController = TextEditingController();

  void register() {
    final String name = nameController.text;
    final String email = emailController.text;
    final String pw = pwController.text;
    final String confirmPw = confirmPwController.text;

    final authCubit = context.read<AuthCubit>();

    if (name.isNotEmpty &&
        email.isNotEmpty &&
        pw.isNotEmpty &&
        confirmPw.isNotEmpty) {
      if (pw == confirmPw) {
        authCubit.register(name, email, pw);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Пароли не совпадают!')));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пожалуйста, заполните все поля')));
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    pwController.dispose();
    confirmPwController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                //logo
                Icon(
                  Icons.lock_open_rounded,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),

                const SizedBox(height: 50),

                //msg
                Text(
                  "Давайте создадим аккаунт для Вас",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 25),

                //email textfield
                MyTextField(
                  controller: nameController,
                  hintText: 'Имя',
                  obscureText: false,
                ),

                const SizedBox(height: 10),

                //email textfield
                MyTextField(
                  controller: emailController,
                  hintText: 'Email',
                  obscureText: false,
                ),

                const SizedBox(height: 10),

                //email textfield
                MyTextField(
                  controller: pwController,
                  hintText: 'Пароль',
                  obscureText: true,
                ),

                const SizedBox(height: 10),

                //email textfield
                MyTextField(
                  controller: confirmPwController,
                  hintText: 'Повторите пароль',
                  obscureText: true,
                ),

                const SizedBox(height: 25),

                //login button
                MyButton(
                  onTap: register,
                  text: 'Зарегистрироваться',
                ),

                const SizedBox(height: 50),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Уже зарегестрированы? ',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary),
                    ),
                    GestureDetector(
                      onTap: widget.togglePages,
                      child: Text(
                        'Войти сейчас',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.inversePrimary,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
