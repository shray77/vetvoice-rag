import 'package:flutter/material.dart';

const kDogBreeds = [
  'French Bulldog', 'Labrador Retriever', 'German Shepherd', 'Golden Retriever',
  'Poodle', 'Cocker Spaniel', 'Yorkshire Terrier', 'Dachshund', 'Beagle',
  'Boxer', 'Shih Tzu', 'Chihuahua', 'Pug', 'Rottweiler', 'Bulldog',
  'German Shorthaired Pointer', 'Siberian Husky', 'Doberman Pinscher',
  'Great Dane', 'Australian Shepherd', 'Miniature Schnauzer', 'Corgi',
  'Border Collie', 'Maltese', 'Basset Hound', 'Shar-Pei', 'Akita',
  'Chow Chow', 'West Highland White Terrier', 'Samoyed', 'Dalmatian',
  'Newfoundland', 'Bernese Mountain Dog', 'Cavalier King Charles Spaniel',
  'Weimaraner', 'Shetland Sheepdog', 'Boston Terrier', 'English Setter',
  'Irish Setter', 'Whippet',
];

const kCatBreeds = [
  'Persian', 'Siamese', 'Maine Coon', 'British Shorthair', 'Ragdoll',
  'Bengal', 'Sphynx', 'Abyssinian', 'Scottish Fold', 'Russian Blue',
];

class BreedField extends StatelessWidget {
  final TextEditingController controller;
  const BreedField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final allBreeds = [...kDogBreeds, ...kCatBreeds];
    return Autocomplete<String>(
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return const Iterable.empty();
        return allBreeds.where(
          (b) => b.toLowerCase().contains(textEditingValue.text.toLowerCase()),
        );
      },
      onSelected: (selection) => controller.text = selection,
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Breed',
            hintText: 'e.g. French Bulldog',
            prefixIcon: Icon(Icons.pets),
            border: OutlineInputBorder(),
          ),
        );
      },
    );
  }
}
