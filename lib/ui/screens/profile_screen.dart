import 'package:flutter/material.dart';

import '../../cloud/models/landmark_models.dart';
import '../../controllers/app_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmEmailController = TextEditingController();
  final _confirmCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.controller.profile.displayName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmEmailController.dispose();
    _confirmCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
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
                      Text('Adventurer profile', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Display name'),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () async {
                          await widget.controller.setDisplayName(_nameController.text);
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
              _buildAuthCard(context),
              const SizedBox(height: 12),
              _buildProgressCard(context),
              const SizedBox(height: 12),
              _buildShareCard(context),
              if (widget.controller.isAdminOrModerator) ...[
                const SizedBox(height: 12),
                _buildAdminCard(context),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAuthCard(BuildContext context) {
    if (widget.controller.isSignedIn) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cloud account', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(widget.controller.signedInEmail ?? ''),
              const SizedBox(height: 8),
              Text(
                widget.controller.isAdminOrModerator
                    ? 'Role: admin/moderator'
                    : 'Role: user',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  await widget.controller.signOut();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cloud sign-in', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      try {
                        await widget.controller.signIn(
                          email: _emailController.text,
                          password: _passwordController.text,
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    },
                    child: const Text('Sign in'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      try {
                        await widget.controller.signUp(
                          email: _emailController.text,
                          password: _passwordController.text,
                          displayName: _nameController.text,
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Account created. Confirm the code below.')),
                        );
                        _confirmEmailController.text = _emailController.text;
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    },
                    child: const Text('Sign up'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmEmailController,
              decoration: const InputDecoration(labelText: 'Confirm email'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmCodeController,
              decoration: const InputDecoration(labelText: 'Confirmation code'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () async {
                try {
                  await widget.controller.confirmSignUp(
                    email: _confirmEmailController.text,
                    code: _confirmCodeController.text,
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Account confirmed. Now sign in.')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              },
              child: const Text('Confirm sign-up'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Progress', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _row('Reveals', '${widget.controller.reveals.length}'),
            _row('Discovered cells', '${widget.controller.discoveredCellsCount}'),
            _row('Coverage', '${widget.controller.coveragePercent.toStringAsFixed(6)}%'),
            _row('Distance walked', '${widget.controller.totalKm.toStringAsFixed(2)} km'),
          ],
        ),
      ),
    );
  }

  Widget _buildShareCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Share map', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Exports your local discovered world progress as JSON.'),
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
    );
  }

  Widget _buildAdminCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Moderation', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () async {
                await widget.controller.loadPendingLandmarks();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Load pending landmarks'),
            ),
            const SizedBox(height: 12),
            ...widget.controller.pendingLandmarks.map(
              (e) => _pendingCard(context, e),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pendingCard(BuildContext context, PendingLandmark item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(item.description),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final url = await widget.controller.getPendingLandmarkReviewUrl(item.landmarkId);
                        if (!context.mounted) return;
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text(item.title),
                            content: Image.network(url),
                          ),
                        );
                      },
                      child: const Text('Preview'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        await widget.controller.moderateLandmark(
                          landmarkId: item.landmarkId,
                          approve: true,
                        );
                      },
                      child: const Text('Approve'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () async {
                        await widget.controller.moderateLandmark(
                          landmarkId: item.landmarkId,
                          approve: false,
                        );
                      },
                      child: const Text('Reject'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}