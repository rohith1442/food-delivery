import 'package:flutter/material.dart';

class ReviewResult {
  const ReviewResult({required this.rating, required this.comment});

  final int rating;
  final String comment;
}

class ReviewDialog extends StatefulWidget {
  const ReviewDialog({super.key, required this.storeName});

  final String storeName;

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  final TextEditingController _commentController = TextEditingController();
  int _rating = 0;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_rating == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a rating.')));
      return;
    }

    Navigator.of(context).pop(
      ReviewResult(rating: _rating, comment: _commentController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rate your order'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'How was your experience with ${widget.storeName}?',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final value = index + 1;

                return IconButton(
                  onPressed: () {
                    setState(() {
                      _rating = value;
                    });
                  },
                  icon: Icon(
                    value <= _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 34,
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLength: 500,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Write a review (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Submit')),
      ],
    );
  }
}
