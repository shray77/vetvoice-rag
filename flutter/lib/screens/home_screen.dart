import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../widgets/image_picker_widget.dart';
import '../widgets/breed_field.dart';
import '../widgets/loading_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _image;
  final _breedCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _breedCtrl.dispose();
    _ageCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _analyze() {
    if (_image == null && _descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a photo or describe symptoms')),
      );
      return;
    }
    context.read<ApiService>().analyzeCase(
          image: _image,
          description: _descCtrl.text.trim(),
          breed: _breedCtrl.text.trim(),
          age: _ageCtrl.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VetVoice'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF43A047)]),
          ),
        ),
      ),
      body: Consumer<ApiService>(
        builder: (context, api, _) {
          if (api.isLoading) {
            return const Center(child: LoadingWidget());
          }
          if (api.result != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushNamed(context, '/result');
            });
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ImagePickerWidget(
                  image: _image,
                  onImageSelected: (f) => setState(() => _image = f),
                  onImageRemoved: () => setState(() => _image = null),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: BreedField(controller: _breedCtrl)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _ageCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Age',
                          hintText: 'e.g. 3 years',
                          prefixIcon: Icon(Icons.cake),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Symptoms',
                    hintText: 'Describe: itching, hair loss, redness, odor, etc.',
                    prefixIcon: Icon(Icons.edit_note),
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _analyze,
                  icon: const Icon(Icons.search),
                  label: const Text('Analyze with AI', style: TextStyle(fontSize: 16)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                if (api.error != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(api.error!, style: const TextStyle(color: Colors.red)),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
