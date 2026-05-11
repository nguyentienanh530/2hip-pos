enum Permission {
  // Account management
  manageAccounts,
  manageEmployees,
  viewEmployees,

  // Products
  viewProducts,
  createProducts,
  editProducts,
  deleteProducts,

  // Orders
  viewOrders,
  createOrders,
  editOrders,
  deleteOrders,

  // Customers
  viewCustomers,
  createCustomers,
  editCustomers,
  deleteCustomers,

  // Suppliers & Imports
  viewSuppliers,
  manageSuppliers,
  manageImports,

  // Financials
  manageExpenses,
  viewReports,

  // Inventory
  manageInventory,
  exportInventory,

  // System
  configureSystem,
  viewActivityLog;

  String get displayName {
    return name
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => ' ${match.group(0)}',
        )
        .trim();
  }
}
