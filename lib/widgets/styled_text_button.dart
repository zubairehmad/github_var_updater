import 'package:flutter/material.dart';

class StyledTextButton extends StatelessWidget {
  final void Function() onPressed;
  final Text text;

  const StyledTextButton({
    super.key,
    required this.onPressed,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF3B71CA),
        foregroundColor: Color(0xFFD6D6D6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: text,
      ),
    );
  }
}