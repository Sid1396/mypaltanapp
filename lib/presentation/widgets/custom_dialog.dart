import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/counter_controller.dart';
import '../../utils/helpers/snackbar_helper.dart';

class CustomDialog {
  static void showSetValueDialog(CounterController controller) {
    final textController = TextEditingController(text: '${controller.value}');

    Get.dialog(
      AlertDialog(
        title: const Text('Set Custom Value'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter a custom counter value:'),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              keyboardType:
                  const TextInputType.numberWithOptions(signed: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
              ],
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Value',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = int.tryParse(textController.text);
              if (parsed != null) {
                controller.setCustomValue(parsed);
                Get.back();
              } else {
                AppSnackbar.error('Invalid Input', 'Please enter a valid integer');
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }
}
