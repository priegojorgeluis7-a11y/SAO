import 'package:flutter/material.dart';

import '../settings/settings_page.dart';
import 'profile_page.dart';

class ProfileSettingsPage extends StatelessWidget {
  const ProfileSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: cs.surface,
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                isScrollable: true,
                labelColor: cs.primary,
                unselectedLabelColor: cs.onSurface.withValues(alpha: 0.55),
                indicatorColor: cs.primary,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.person_rounded, size: 18),
                    text: 'Perfil',
                  ),
                  Tab(
                    icon: Icon(Icons.tune_rounded, size: 18),
                    text: 'Configuración',
                  ),
                ],
              ),
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                ProfilePage(),
                SettingsPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
