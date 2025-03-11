import 'package:flutter/material.dart';
import '../models/settings.dart';
import '../services/settings_service.dart';

class SettingsPanel extends StatefulWidget {
  final SettingsService settingsService;

  const SettingsPanel({
    super.key,
    required this.settingsService,
  });

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  late Settings _settings;
  final _ollamaUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _settings = widget.settingsService.settings;
    _ollamaUrlController.text = _settings.ollamaUrl;
  }

  @override
  void dispose() {
    _ollamaUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'General Settings',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16.0),
                TextField(
                  controller: _ollamaUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Ollama URL',
                    hintText: 'http://localhost:11434',
                  ),
                  onChanged: (value) {
                    widget.settingsService.updateOllamaUrl(value);
                  },
                ),
                const SizedBox(height: 16.0),
                Row(
                  children: [
                    const Text('Dark Mode'),
                    const Spacer(),
                    Switch(
                      value: _settings.darkMode,
                      onChanged: (value) {
                        setState(() {
                          widget.settingsService.updateDarkMode(value);
                          _settings = widget.settingsService.settings;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),
                Row(
                  children: [
                    const Text('Font Size'),
                    const Spacer(),
                    DropdownButton<double>(
                      value: _settings.fontSize,
                      items: [12.0, 14.0, 16.0, 18.0, 20.0].map((size) {
                        return DropdownMenuItem(
                          value: size,
                          child: Text('${size.toInt()}'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            widget.settingsService.updateFontSize(value);
                            _settings = widget.settingsService.settings;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16.0),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Display Settings',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16.0),
                SwitchListTile(
                  title: const Text('Show Images'),
                  value: _settings.showImages,
                  onChanged: (value) {
                    setState(() {
                      widget.settingsService.updateShowImages(value);
                      _settings = widget.settingsService.settings;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Show Related Articles'),
                  value: _settings.showRelatedArticles,
                  onChanged: (value) {
                    setState(() {
                      widget.settingsService.updateShowRelatedArticles(value);
                      _settings = widget.settingsService.settings;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Show Categories'),
                  value: _settings.showCategories,
                  onChanged: (value) {
                    setState(() {
                      widget.settingsService.updateShowCategories(value);
                      _settings = widget.settingsService.settings;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16.0),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Performance Settings',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16.0),
                Row(
                  children: [
                    const Text('Max Image Size'),
                    const Spacer(),
                    DropdownButton<int>(
                      value: _settings.maxImageSize,
                      items: [256, 512, 1024, 2048].map((size) {
                        return DropdownMenuItem(
                          value: size,
                          child: Text('${size}px'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            widget.settingsService.updateMaxImageSize(value);
                            _settings = widget.settingsService.settings;
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),
                Row(
                  children: [
                    const Text('Max Batch Size'),
                    const Spacer(),
                    DropdownButton<int>(
                      value: _settings.maxBatchSize,
                      items: [8, 16, 32, 64].map((size) {
                        return DropdownMenuItem(
                          value: size,
                          child: Text('$size'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            widget.settingsService.updateMaxBatchSize(value);
                            _settings = widget.settingsService.settings;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
} 