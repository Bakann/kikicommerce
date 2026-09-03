import 'package:flutter/material.dart';

class ProductSizeDropdown extends StatefulWidget {
  const ProductSizeDropdown({super.key});

  @override
  State<ProductSizeDropdown> createState() => _ProductSizeDropdownState();
}

class _ProductSizeDropdownState extends State<ProductSizeDropdown> {
  String _selected = 'Small';
  static const _sizes = ['Small', 'Medium', 'Large'];
  static const _borderColor = Color(0xFFD9D6D0);

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      fontSize: 16,
      color: Color(0xFF2A2A28),
      fontWeight: FontWeight.w400,
      height: 1.1,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(bottom: BorderSide(color: _borderColor, width: 1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selected,
          isExpanded: true,
          icon: const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: Color(0xFF7B7F82),
            ),
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(2),
          padding: const EdgeInsets.symmetric(vertical: 12),
          style: textStyle,
          items: _sizes
              .map(
                (size) => DropdownMenuItem<String>(
                  value: size,
                  child: Text(size, style: textStyle),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selected = value);
            }
          },
        ),
      ),
    );
  }
}
