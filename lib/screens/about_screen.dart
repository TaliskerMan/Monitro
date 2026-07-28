import 'package:flutter/material.dart';
import 'package:monitro/theme/app_theme.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen widget displaying program metadata, licensing terms, and local DB configurations.
///
/// Includes visual code block instructions describing the manual installation and configuration
/// steps needed to initialize MariaDB to store statistics logs.
class AboutScreen extends StatelessWidget {
  /// Creates an [AboutScreen] instance.
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('About Monitro')),
      body: ListView(
        padding: const EdgeInsets.all(32),
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/monitro_icon.png',
                width: 80,
                height: 80,
              ),
              const SizedBox(width: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Monitro',
                    style: TextStyle(
                      color: AppTheme.accent,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Local System Observability Platform',
                    style: TextStyle(color: AppTheme.muted, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Text(
                          'Version ${snapshot.data!.version}+${snapshot.data!.buildNumber} (Linux)',
                          style: TextStyle(
                            color: AppTheme.onSurface.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        );
                      }
                      return Text(
                        'Loading version...',
                        style: TextStyle(
                          color: AppTheme.onSurface.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 64, color: AppTheme.surfaceAlt),
          const _SectionHeader('Author Details'),
          const _InfoRow('Copyright', 'Chuck Talk'),
          const _InfoRow('Email', 'chuck@nordheim.online'),
          const _InfoRow('License', 'MIT License'),
          const _LinkRow(
              'Source Code', 'https://github.com/TaliskerMan/Monitro'),
          const SizedBox(height: 32),
          const _SectionHeader('Release Integrity'),
          const _InfoRow('GPG Signature', 'Detached signed (.asc)'),
          const _InfoRow('SHA512 Hash sum', 'Included in release artifacts'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Text(
              'To verify the integrity of the .deb package, download the corresponding .asc file and utilize gpg --verify, or check the SHA512 hash against the release checksums.',
              style: TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
          ),
          const Divider(height: 64, color: AppTheme.surfaceAlt),
          const _SectionHeader('MariaDB Setup Documentation'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Text(
              'Monitro relies on MariaDB for high-performance localized telemetry storage. The database daemon is NOT included with this application and must be installed manually. Please follow the instructions below to configure MariaDB for Monitro.',
              style: TextStyle(
                color: AppTheme.onSurface,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _CodeBlockHeader('1. Installation'),
          const _CodeBlock('sudo apt update\nsudo apt install mariadb-server'),
          const SizedBox(height: 16),
          const _CodeBlockHeader('2. Secure Installation'),
          const _CodeBlock(
            'sudo mariadb-secure-installation\n# Follow the prompts to configure root access securely.',
          ),
          const SizedBox(height: 16),
          const _CodeBlockHeader('3. Database Configuration'),
          const Padding(
            padding: EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Text(
              'Log into the MariaDB instance and execute the following queries to establish the database and user permissions for the collector script.',
              style: TextStyle(color: AppTheme.muted, fontSize: 13),
            ),
          ),
          const _CodeBlock('''
sudo mysql -u root -p
          
CREATE DATABASE monitro_db;
CREATE USER 'monitro_user'@'localhost' IDENTIFIED BY 'YOUR_SECURE_PASSWORD';
GRANT ALL PRIVILEGES ON monitro_db.* TO 'monitro_user'@'localhost';
FLUSH PRIVILEGES;
EXIT;'''),
          const SizedBox(height: 16),
          const _CodeBlockHeader('4. Monitro Configuration'),
          const Padding(
            padding: EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Text(
              'Once the database is configured, ensure your /opt/monitro/config/monitro.yaml reflects the changes. Example:',
              style: TextStyle(color: AppTheme.muted, fontSize: 13),
            ),
          ),
          const _CodeBlock('''
database:
  host: "127.0.0.1"
  port: 3306
  name: "monitro_db"
  user: "monitro_user"
  password: "monitro_secure_password"'''),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

/// Renders a section header label with accent colors.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(
          text,
          style: const TextStyle(
            color: AppTheme.accent,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.8,
          ),
        ),
      );
}

/// Renders a horizontal label-value text pair.
class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140,
              child: Text(
                label,
                style: const TextStyle(color: AppTheme.muted, fontSize: 14),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  color: AppTheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
}

/// Renders an interactive link row that triggers launchUrl calls.
class _LinkRow extends StatelessWidget {
  const _LinkRow(this.label, this.url);
  final String label;
  final String url;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140,
              child: Text(
                label,
                style: const TextStyle(color: AppTheme.muted, fontSize: 14),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () => launchUrl(Uri.parse(url)),
                child: Text(
                  url,
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

/// Title element preceding code blocks.
class _CodeBlockHeader extends StatelessWidget {
  const _CodeBlockHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 16, bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: AppTheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      );
}

/// Visual code container block rendering pre-formatted selectable text.
class _CodeBlock extends StatelessWidget {
  const _CodeBlock(this.code);
  final String code;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAlt.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.surfaceAlt),
        ),
        child: SelectableText(
          code,
          style: const TextStyle(
            fontFamily: 'monospace',
            color: AppTheme.onSurface,
            fontSize: 13,
          ),
        ),
      );
}
