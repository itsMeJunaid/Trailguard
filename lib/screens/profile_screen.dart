import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../core/platform/local_files.dart';
import '../core/theme.dart';
import '../widgets/pressable.dart';
import '../models/user_profile.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final bool onboarding;
  const ProfileScreen({super.key, this.onboarding = false});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _allergies = TextEditingController();
  final _medications = TextEditingController();
  final _conditions = TextEditingController();
  final _emergencyName = TextEditingController();
  final _emergencyPhone = TextEditingController();
  final _picker = ImagePicker();

  String? _bloodGroup;
  String? _picPath;
  bool _seeded = false;

  static const _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'Unknown'
  ];

  void _seed(UserProfile? p) {
    if (_seeded) return;
    _seeded = true;
    if (p == null) return;
    _name.text = p.name;
    _age.text = p.age?.toString() ?? '';
    _allergies.text = p.allergies ?? '';
    _medications.text = p.medications ?? '';
    _conditions.text = p.conditions ?? '';
    _emergencyName.text = p.emergencyName ?? '';
    _emergencyPhone.text = p.emergencyPhone ?? '';
    _bloodGroup = p.bloodGroup;
    _picPath = p.profilePicPath;
  }

  Future<void> _pickPic() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (x == null) return;
    final saved = await ref
        .read(profileProvider.notifier)
        .setPicture(x.path);
    setState(() => _picPath = saved);
  }

  Future<void> _save() async {
    final existing = ref.read(profileProvider);
    final now = DateTime.now();
    final profile = UserProfile(
      name: _name.text.trim(),
      age: int.tryParse(_age.text.trim()),
      bloodGroup: _bloodGroup,
      allergies: _allergies.text.trim().isEmpty ? null : _allergies.text.trim(),
      medications: _medications.text.trim().isEmpty
          ? null
          : _medications.text.trim(),
      conditions: _conditions.text.trim().isEmpty
          ? null
          : _conditions.text.trim(),
      emergencyName: _emergencyName.text.trim().isEmpty
          ? null
          : _emergencyName.text.trim(),
      emergencyPhone: _emergencyPhone.text.trim().isEmpty
          ? null
          : _emergencyPhone.text.trim(),
      profilePicPath: _picPath,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    if (profile.name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter your name.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    await ref.read(profileProvider.notifier).save(profile);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppTheme.primary,
      behavior: SnackBarBehavior.floating,
      content: Text(widget.onboarding
          ? 'Profile saved — welcome, ${profile.name.split(" ").first}.'
          : 'Profile updated.'),
    ));
    if (widget.onboarding) {
      context.go('/home');
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _allergies.dispose();
    _medications.dispose();
    _conditions.dispose();
    _emergencyName.dispose();
    _emergencyPhone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existing = ref.watch(profileProvider);
    _seed(existing);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: widget.onboarding
            ? null
            : IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded,
                    color: AppTheme.primary),
                onPressed: () => Navigator.maybePop(context),
              ),
        title: Text(
          widget.onboarding ? 'Create Profile' : 'My Profile',
          style: AppTheme.h2(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          // Avatar picker
          Center(
            child: Pressable(
              circle: true,
              onPressed: _pickPic,
              label: 'Change profile photo',
              tooltip: 'Change photo',
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryFixed,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppTheme.surfaceContainerLowest, width: 4),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _picPath != null && localFileExists(_picPath!)
                        ? localImage(_picPath!, fit: BoxFit.cover)
                        : const Icon(Icons.person_rounded,
                            color: AppTheme.primary, size: 56),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 16),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          _Section('BASIC INFO'),
          _Field(label: 'Full name', controller: _name, icon: Icons.person),
          _Field(
            label: 'Age',
            controller: _age,
            icon: Icons.cake_rounded,
            keyboardType: TextInputType.number,
          ),
          _BloodGroupDropdown(
            value: _bloodGroup,
            onChanged: (v) => setState(() => _bloodGroup = v),
          ),

          const SizedBox(height: 20),
          _Section('MEDICAL (for emergencies)'),
          _Field(
            label: 'Medical conditions (e.g. asthma, diabetes)',
            controller: _conditions,
            icon: Icons.medical_services_rounded,
            maxLines: 2,
          ),
          _Field(
            label: 'Allergies (foods, bee stings, meds)',
            controller: _allergies,
            icon: Icons.warning_amber_rounded,
            maxLines: 2,
          ),
          _Field(
            label: 'Current medications',
            controller: _medications,
            icon: Icons.medication_rounded,
            maxLines: 2,
          ),

          const SizedBox(height: 20),
          _Section('EMERGENCY CONTACT'),
          _Field(
            label: 'Contact name',
            controller: _emergencyName,
            icon: Icons.contact_emergency_rounded,
          ),
          _Field(
            label: 'Contact phone',
            controller: _emergencyPhone,
            icon: Icons.phone_rounded,
            keyboardType: TextInputType.phone,
          ),

          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.secondaryFixed,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_rounded,
                    color: AppTheme.onSecondaryFixedVariant, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Stored locally on your device only. Never sent to a server.',
                    style: AppTheme.body(
                        color: AppTheme.onSecondaryFixedVariant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: Text(widget.onboarding ? 'CONTINUE' : 'SAVE PROFILE'),
            ),
          ),

          if (!widget.onboarding) ...[
            const SizedBox(height: 28),
            _Section('SETTINGS'),
            _MenuRow(
              icon: Icons.auto_awesome_rounded,
              iconBg: AppTheme.primaryFixed,
              iconColor: AppTheme.primary,
              title: 'Model Setup',
              subtitle: 'Download & load Gemma 4 LiteRT-LM',
              onTap: () => context.go('/settings'),
            ),
            const SizedBox(height: 10),
            _MenuRow(
              icon: Icons.info_outline_rounded,
              iconBg: AppTheme.secondaryFixed,
              iconColor: AppTheme.onSecondaryFixedVariant,
              title: 'About & Credits',
              subtitle: 'Developer · License · Free to use',
              onTap: () => context.go('/about'),
            ),
          ],
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTheme.h3(color: AppTheme.primary)),
                    Text(subtitle, style: AppTheme.body()),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
      child: Text(text, style: AppTheme.label(color: AppTheme.primary)),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;
  const _Field({
    required this.label,
    required this.controller,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        minLines: 1,
        style: AppTheme.body(color: AppTheme.onSurface),
        decoration: InputDecoration(
          hintText: label,
          prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
        ),
      ),
    );
  }
}

class _BloodGroupDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const _BloodGroupDropdown({required this.value, required this.onChanged});

  static const _groups = _ProfileScreenState._bloodGroups;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: const InputDecoration(
          hintText: 'Blood group',
          prefixIcon: Icon(Icons.bloodtype_rounded,
              color: AppTheme.primary, size: 20),
        ),
        items: _groups
            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
