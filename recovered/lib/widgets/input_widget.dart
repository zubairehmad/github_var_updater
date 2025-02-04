import 'package:flutter/material.dart';

class InputWidget extends StatelessWidget {

  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? initialValue;
  final bool readOnly;
  final String prefixText;

  const InputWidget({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.initialValue,
    this.prefixText = "",
    this.readOnly = false
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          Text(
            prefixText,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: TextFormField(
              controller: controller,
              readOnly: readOnly,
              initialValue: initialValue,
              decoration: InputDecoration(
                labelText:  labelText,
                hintText: hintText,
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ]
      ),
    );
  }
}