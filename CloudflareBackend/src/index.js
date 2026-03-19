// Inventory API - Cloudflare Worker
// Routes:
//   GET    /api/products
//   POST   /api/products
//   PUT    /api/products/:id
//   DELETE /api/products/:id
//   GET    /api/transactions
//   POST   /api/transactions
//   GET    /api/sync?since=ISO_DATE
//   POST   /api/sync/push

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function unauthorized() {
  return json({ error: 'Unauthorized' }, 401);
}

function verifyToken(request, env) {
  const auth = request.headers.get('Authorization') || '';
  const token = auth.replace('Bearer ', '');
  return token === env.API_SECRET;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    if (method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    if (!verifyToken(request, env)) return unauthorized();

    // --- PRODUCTS ---
    if (path === '/api/products' && method === 'GET') {
      return await getProducts(env);
    }
    if (path === '/api/products' && method === 'POST') {
      const body = await request.json();
      return await upsertProduct(env, body);
    }
    if (path.startsWith('/api/products/') && method === 'PUT') {
      const id = path.split('/')[3];
      const body = await request.json();
      return await upsertProduct(env, { ...body, id });
    }
    if (path.startsWith('/api/products/') && method === 'DELETE') {
      const id = path.split('/')[3];
      return await deleteProduct(env, id);
    }

    // --- TRANSACTIONS ---
    if (path === '/api/transactions' && method === 'GET') {
      const limit = url.searchParams.get('limit') || '100';
      const productId = url.searchParams.get('productId');
      return await getTransactions(env, parseInt(limit), productId);
    }
    if (path === '/api/transactions' && method === 'POST') {
      const body = await request.json();
      return await insertTransaction(env, body);
    }

    // --- SYNC ---
    if (path === '/api/sync' && method === 'GET') {
      const since = url.searchParams.get('since');
      return await syncPull(env, since);
    }
    if (path === '/api/sync/push' && method === 'POST') {
      const body = await request.json();
      return await syncPush(env, body);
    }

    return json({ error: 'Not found' }, 404);
  },
};

// ---- PRODUCTS ----

async function getProducts(env) {
  const { results } = await env.DB.prepare(
    'SELECT * FROM products WHERE deleted = 0 ORDER BY name ASC'
  ).all();
  return json(results);
}

async function upsertProduct(env, p) {
  await env.DB.prepare(`
    INSERT INTO products (id, name, sku, barcode, category, unit, min_stock, current_stock, price, location, note, created_at, updated_at, deleted)
    VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11,?12,?13,0)
    ON CONFLICT(id) DO UPDATE SET
      name=excluded.name, sku=excluded.sku, barcode=excluded.barcode,
      category=excluded.category, unit=excluded.unit, min_stock=excluded.min_stock,
      current_stock=excluded.current_stock, price=excluded.price,
      location=excluded.location, note=excluded.note, updated_at=excluded.updated_at
  `).bind(
    p.id, p.name, p.sku, p.barcode, p.category, p.unit,
    p.minStock ?? 0, p.currentStock ?? 0, p.price ?? 0,
    p.location ?? '', p.note ?? '',
    p.createdAt ?? new Date().toISOString(),
    new Date().toISOString()
  ).run();
  return json({ success: true, id: p.id });
}

async function deleteProduct(env, id) {
  await env.DB.prepare(
    'UPDATE products SET deleted = 1, updated_at = ?1 WHERE id = ?2'
  ).bind(new Date().toISOString(), id).run();
  return json({ success: true });
}

// ---- TRANSACTIONS ----

async function getTransactions(env, limit, productId) {
  let query = 'SELECT * FROM transactions ORDER BY timestamp DESC LIMIT ?1';
  let params = [limit];
  if (productId) {
    query = 'SELECT * FROM transactions WHERE product_id = ?2 ORDER BY timestamp DESC LIMIT ?1';
    params = [limit, productId];
  }
  const stmt = env.DB.prepare(query);
  const { results } = await stmt.bind(...params).all();
  return json(results);
}

async function insertTransaction(env, tx) {
  await env.DB.prepare(`
    INSERT OR IGNORE INTO transactions
      (id, product_id, product_name, type, quantity, note, delivery_note, timestamp, user, stock_before, stock_after)
    VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11)
  `).bind(
    tx.id, tx.productId, tx.productName, tx.type,
    tx.quantity, tx.note ?? '', tx.deliveryNote ?? '',
    tx.timestamp ?? new Date().toISOString(),
    tx.user ?? '', tx.stockBefore ?? 0, tx.stockAfter ?? 0
  ).run();
  return json({ success: true, id: tx.id });
}

// ---- SYNC ----

async function syncPull(env, since) {
  let products, transactions;
  if (since) {
    const r1 = await env.DB.prepare(
      'SELECT * FROM products WHERE updated_at > ?1'
    ).bind(since).all();
    const r2 = await env.DB.prepare(
      'SELECT * FROM transactions WHERE timestamp > ?1 ORDER BY timestamp DESC LIMIT 500'
    ).bind(since).all();
    products = r1.results;
    transactions = r2.results;
  } else {
    const r1 = await env.DB.prepare('SELECT * FROM products WHERE deleted = 0').all();
    const r2 = await env.DB.prepare('SELECT * FROM transactions ORDER BY timestamp DESC LIMIT 1000').all();
    products = r1.results;
    transactions = r2.results;
  }
  return json({ products, transactions, syncedAt: new Date().toISOString() });
}

async function syncPush(env, body) {
  const { products = [], transactions = [] } = body;
  let productCount = 0;
  let txCount = 0;

  for (const p of products) {
    await upsertProduct(env, p);
    productCount++;
  }
  for (const tx of transactions) {
    await insertTransaction(env, tx);
    txCount++;
  }

  return json({
    success: true,
    products: productCount,
    transactions: txCount,
    syncedAt: new Date().toISOString(),
  });
}
