import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();
    final result = api.result;

    if (result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Result')),
        body: const Center(child: Text('No results')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis Result'),
        actions: [
          IconButton(
            onPressed: () => Share.share(result.toShareText()),
            icon: const Icon(Icons.share),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Success header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Analysis Complete',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.green.shade900,
                            )),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Conditions chips
            if (result.conditions.isNotEmpty) ...[
              Text('Detected Conditions:', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: result.conditions
                    .map((c) => Chip(
                          label: Text(c),
                          backgroundColor: Colors.green.shade100,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Diagnosis
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Diagnosis', style: Theme.of(context).textTheme.titleMedium),
                    const Divider(),
                    Text(result.diagnosis, style: const TextStyle(height: 1.5)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // VLM Analysis (expandable)
            if (result.vlmAnalysis.isNotEmpty)
              ExpansionTile(
                title: const Text('Image Analysis (VLM)'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(result.vlmAnalysis, style: const TextStyle(height: 1.4)),
                  ),
                ],
              ),
            const SizedBox(height: 16),

            // Disclaimer
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber, color: Colors.amber.shade800),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(result.disclaimer,
                        style: TextStyle(color: Colors.amber.shade900, fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      api.reset();
                      Navigator.pushReplacementNamed(context, '/');
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('New Analysis'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Share.share(result.toShareText()),
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
