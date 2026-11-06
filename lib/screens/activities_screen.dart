import 'package:flutter/material.dart';

const _activities = [
  (Icons.self_improvement, 'Stretch', 'Loosen your neck and shoulders for two minutes.'),
  (Icons.edit_note, 'Journal', 'Write down three things from today.'),
  (Icons.menu_book, 'Read', 'A few pages of a paper book.'),
  (Icons.local_drink, 'Drink water', 'Get a glass of water away from your phone.'),
  (Icons.alarm, 'Set an alarm and sleep', 'Put your phone across the room.'),
];

class ActivitiesScreen extends StatelessWidget {
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Try one of these instead')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final (icon, title, hint) in _activities)
              Card(child: ListTile(leading: Icon(icon), title: Text(title), subtitle: Text(hint))),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
          ],
        ),
      );
}
