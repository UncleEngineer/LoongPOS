import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'package:sunmi_printer_plus/enums.dart';
import 'package:sunmi_printer_plus/sunmi_style.dart';

void main() {
  runApp(const POSApp());
}

class POSApp extends StatelessWidget {
  const POSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

Future<void> initialize() async {
  await SunmiPrinter.bindingPrinter();
  await SunmiPrinter.initPrinter();
  await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
}

class Product {
  final int? id;
  final String name;
  final double price;

  Product({this.id, required this.name, required this.price});

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'price': price};
  }

  static Product fromMap(Map<String, dynamic> map) {
    return Product(id: map['id'], name: map['name'], price: map['price']);
  }
}

class ProductListPage extends StatelessWidget {
  final List<Product> products;
  final void Function(Product) onEdit;
  final void Function(Product) onDelete;

  const ProductListPage({
    super.key,
    required this.products,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Products')),
      body: ListView.builder(
        itemCount: products.length,
        itemBuilder: (_, i) {
          final product = products[i];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            child: ListTile(
              title: Text(product.name),
              subtitle: Text("฿${product.price}"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.amber),
                    onPressed: () => onEdit(product),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => onDelete(product),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class CartItem {
  final Product product;
  int quantity;

  CartItem(this.product, {this.quantity = 1});

  double get total => product.price * quantity;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Database db;
  List<Product> products = [];
  List<CartItem> cart = [];
  int currentPage = 0;

  @override
  void initState() {
    super.initState();
    _initDB();
  }

  Future<void> _initDB() async {
    db = await openDatabase(
      join(await getDatabasesPath(), 'pos.db'),
      onCreate: (db, version) {
        return db.execute('''CREATE TABLE products (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          price REAL
        )''');
      },
      version: 1,
    );
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final List<Map<String, dynamic>> maps = await db.query('products');
    setState(() {
      products = List.generate(maps.length, (i) => Product.fromMap(maps[i]));
    });
  }

  Future<void> _addProduct(String name, double price) async {
    await db.insert('products', {'name': name, 'price': price});
    _loadProducts();
  }

  Future<void> _editProduct(BuildContext context, Product product) async {
    final nameController = TextEditingController(text: product.name);
    final priceController = TextEditingController(
      text: product.price.toString(),
    );

    showDialog(
      context: context,
      builder:
          (BuildContext dialogContext) => AlertDialog(
            title: const Text('Edit Product'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Price'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  final name = nameController.text;
                  final price = double.tryParse(priceController.text) ?? 0;
                  if (name.isNotEmpty && price > 0) {
                    await db.update(
                      'products',
                      {'name': name, 'price': price},
                      where: 'id = ?',
                      whereArgs: [product.id],
                    );
                    _loadProducts();
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteProduct(Product product) async {
    await db.delete('products', where: 'id = ?', whereArgs: [product.id]);
    _loadProducts();
  }

  double get total => cart.fold(0, (sum, item) => sum + item.total);

  void _addToCart(Product product) {
    setState(() {
      final existing =
          cart.where((item) => item.product.id == product.id).toList();
      if (existing.isNotEmpty) {
        existing.first.quantity++;
      } else {
        cart.add(CartItem(product));
      }
    });
  }

  Future<void> _printReceipt() async {
    final transactionId = DateTime.now().millisecondsSinceEpoch;
    final date = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    await initialize();
    await SunmiPrinter.startTransactionPrint(true);
    await SunmiPrinter.printText(
      'Uncle Coffee Shop',
      style: SunmiStyle(bold: true, align: SunmiPrintAlign.CENTER),
    );
    await SunmiPrinter.printText(
      'Date: $date',
      style: SunmiStyle(align: SunmiPrintAlign.CENTER),
    );
    await SunmiPrinter.printText(
      'Transaction ID: $transactionId',
      style: SunmiStyle(align: SunmiPrintAlign.CENTER),
    );
    await SunmiPrinter.lineWrap(1);

    for (var item in cart) {
      await SunmiPrinter.printText(
        "${item.product.name} x${item.quantity} 	 ${item.total.toStringAsFixed(2)}",
      );
    }

    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.printText(
      "Total: 	${total.toStringAsFixed(2)}",
      style: SunmiStyle(bold: true),
    );
    await SunmiPrinter.lineWrap(3);
    await SunmiPrinter.submitTransactionPrint();
    await SunmiPrinter.exitTransactionPrint();
  }

  void _showAddProductDialog(BuildContext context) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    showDialog(
      context: context,
      builder:
          (BuildContext dialogContext) => AlertDialog(
            title: const Text('Add Product'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Price'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  final name = nameController.text;
                  final price = double.tryParse(priceController.text) ?? 0;
                  if (name.isNotEmpty && price > 0) {
                    _addProduct(name, price);
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int pageCount = (products.length / 9).ceil();
    int start = currentPage * 9;
    int end = (start + 9).clamp(0, products.length);
    List<Product> pageProducts = products.sublist(start, end);

    return Scaffold(
      appBar: AppBar(
        title: const Text('POS System'),
        actions: [
          IconButton(
            icon: const Icon(Icons.view_list),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => ProductListPage(
                          products: products,
                          onEdit: (product) => _editProduct(context, product),
                          onDelete: _deleteProduct,
                        ),
                  ),
                ),
          ),
          IconButton(
            onPressed: () => _showAddProductDialog(context),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed:
                      currentPage > 0
                          ? () => setState(() => currentPage--)
                          : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                for (int i = 0; i < pageCount; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            i == currentPage ? Colors.orange : Colors.grey,
                        minimumSize: const Size(36, 36),
                      ),
                      onPressed: () => setState(() => currentPage = i),
                      child: Text('${i + 1}'),
                    ),
                  ),
                IconButton(
                  onPressed:
                      currentPage < pageCount - 1
                          ? () => setState(() => currentPage++)
                          : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1,
            padding: const EdgeInsets.all(8),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children:
                pageProducts.map((product) {
                  return SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => _addToCart(product),
                      child: Center(
                        child: Text(product.name, textAlign: TextAlign.center),
                      ),
                    ),
                  );
                }).toList(),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: cart.length,
              itemBuilder: (_, i) {
                final item = cart[i];
                return ListTile(
                  title: Text(item.product.name),
                  subtitle: Text("Quantity: ${item.quantity}"),
                  trailing: Text(item.total.toStringAsFixed(2)),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  "Total: ${total.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed:
                      cart.isEmpty
                          ? null
                          : () async {
                            await _printReceipt(); // ต้องใส่ await!
                            setState(() => cart.clear());
                          },
                  child: const Text('Print Receipt'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
