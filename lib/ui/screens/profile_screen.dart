import 'package:flutter/material.dart';

import '../../controllers/app_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.controller.profile.displayName,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final displayName = widget.controller.profile.displayName;

        if (_nameController.text != displayName) {
          _nameController.value = _nameController.value.copyWith(
            text: displayName,
            selection: TextSelection.collapsed(offset: displayName.length),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Adventurer profile',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Display name',
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () async {
                          await widget.controller
                              .setDisplayName(_nameController.text);

                          if (!context.mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Profile saved.')),
                          );
                        },
                        child: const Text('Save profile'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Progress',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      _RowItem(
                        label: 'Reveals',
                        value: '${widget.controller.reveals.length}',
                      ),
                      _RowItem(
                        label: 'Discovered cells',
                        value: '${widget.controller.discoveredCellsCount}',
                      ),
                      _RowItem(
                        label: 'Coverage',
                        value:
                            '${widget.controller.coveragePercent.toStringAsFixed(3)}%',
                      ),
                      _RowItem(
                        label: 'Distance walked',
                        value:
                            '${widget.controller.totalKm.toStringAsFixed(1)} km',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share map',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Exports your discovered world progress as JSON so friends can import or compare later.',
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () async {
                          await widget.controller.share();
                        },
                        icon: const Icon(Icons.ios_share),
                        label: const Text('Share progress export'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RowItem extends StatelessWidget {
  const _RowItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}