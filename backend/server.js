const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const multer = require('multer');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

// Serve uploaded files publicly
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/postgres',
});

const JWT_SECRET = process.env.JWT_SECRET || 'super-secret-key';

// --- AUTHENTICATION ---
app.post('/api/db/auth/signup', async (req, res) => {
  const { email, password, data } = req.body;
  try {
    const hashedPassword = await bcrypt.hash(password, 10);
    // Insert into profiles or a custom users table
    const { rows } = await pool.query(
      `INSERT INTO profiles (id, auth_email, first_name, last_name, role, password_hash) 
       VALUES (gen_random_uuid(), $1, $2, $3, $4, $5) RETURNING *`,
      [email, data?.first_name, data?.last_name, data?.role || 'employee', hashedPassword]
    );
    const userRow = rows[0];
    const user = { 
        id: userRow.id, 
        email: userRow.auth_email, 
        user_metadata: { employee_id: userRow.employee_id || '' } 
    };
    res.json({ user, error: null });
  } catch (err) {
    res.status(400).json({ user: null, error: err.message });
  }
});

app.post('/api/db/auth/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    // We assume profiles has an auth_email column as seen in the schema
    const { rows } = await pool.query('SELECT * FROM profiles WHERE auth_email = $1', [email]);
    if (rows.length === 0) return res.status(400).json({ error: 'User not found' });
    
    const userRow = rows[0];
    
    // VERIFY PASSWORD
    const isPasswordValid = await bcrypt.compare(password, userRow.password_hash);
    if (!isPasswordValid) return res.status(401).json({ error: 'Invalid password' });

    const user = { 
        id: userRow.id, 
        email: userRow.auth_email, 
        user_metadata: { employee_id: userRow.employee_id || '' } 
    };
    
    const token = jwt.sign({ id: user.id, email: user.email }, JWT_SECRET, { expiresIn: '1d' });
    res.json({ user, token, error: null });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- STORAGE ---
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const dir = path.join(__dirname, 'uploads', req.body.bucket || 'evidence');
    fs.mkdirSync(dir, { recursive: true });
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    cb(null, Date.now() + '-' + file.originalname);
  }
});
const upload = multer({ storage });

app.post('/api/db/storage/upload', upload.single('file'), (req, res) => {
  try {
    const filePath = req.file.filename; 
    res.json({ data: { path: filePath }, error: null });
  } catch (err) {
    res.status(500).json({ data: null, error: err.message });
  }
});

app.post('/api/db/storage/remove', (req, res) => {
  const { bucket, paths } = req.body;
  try {
    paths.forEach(p => {
      const fullPath = path.join(__dirname, 'uploads', bucket, p);
      if (fs.existsSync(fullPath)) fs.unlinkSync(fullPath);
    });
    res.json({ data: true, error: null });
  } catch (err) {
    res.status(500).json({ data: null, error: err.message });
  }
});

// --- RPC CALLS ---
app.post('/api/db/rpc', async (req, res) => {
  const { fn, params } = req.body;
  try {
    if (fn === 'get_reports_hierarchy') {
      const { rows } = await pool.query(`SELECT * FROM get_reports_hierarchy($1)`, [params.manager_uuid]);
      res.json({ data: rows, error: null });
    } else {
      res.status(400).json({ error: 'RPC function not implemented in Node backend' });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- SMART QUERY BUILDER (Replaces Supabase .from()) ---
app.post('/api/db/query', async (req, res) => {
  const { table, action, query, payload } = req.body;
  try {
    let sql = '';
    let values = [];
    let valIndex = 1;

    if (action === 'select') {
      if (table === 'global_themes' && query.select.includes('global_subthemes')) {
          let baseQuery = 'SELECT * FROM global_themes';
          let baseParams = [];
          if (query.filters && query.filters.length > 0) {
              const filter = query.filters[0];
              if (filter.type === 'eq') {
                  baseQuery += ' WHERE ' + filter.col + ' = $1';
                  baseParams.push(filter.val);
              }
          }
          const { rows: themes } = await pool.query(baseQuery, baseParams);
          const { rows: subthemes } = await pool.query('SELECT * FROM global_subthemes');
          const enriched = themes.map(t => ({
              ...t, global_subthemes: subthemes.filter(s => s.theme_id === t.id)
          }));
          return res.json({ data: enriched, error: null });
      } else if (table === 'employee_subtheme_alignment' && query.select.includes('global_subthemes')) {
          let baseQuery = 'SELECT * FROM employee_subtheme_alignment';
          let baseParams = [];
          if (query.filters && query.filters.length > 0) {
              const filter = query.filters[0];
              if (filter.type === 'in') {
                 baseQuery += ' WHERE ' + filter.col + ' = ANY($1)';
                 baseParams.push(filter.val);
              } else if (filter.type === 'eq') {
                 baseQuery += ' WHERE ' + filter.col + ' = $1';
                 baseParams.push(filter.val);
              }
          }
          const { rows: alignments } = await pool.query(baseQuery, baseParams);
          const { rows: subthemes } = await pool.query('SELECT * FROM global_subthemes');
          const enriched = alignments.map(a => ({
              ...a, global_subthemes: subthemes.find(s => s.id === a.subtheme_id) || null
          }));
          return res.json({ data: enriched, error: null });
      } else {
          sql = `SELECT * FROM ${table}`;
          if (query.filters && query.filters.length > 0) {
              const clauses = [];
              query.filters.forEach(f => {
                 if (f.type === 'eq') {
                     clauses.push(`${f.col} = $${valIndex++}`); values.push(f.val);
                 } else if (f.type === 'in') {
                     clauses.push(`"${f.col}" = ANY($${valIndex++})`); values.push(f.val);
                 } else if (f.type === 'or') {
                     // Better OR parser for patterns like "auth_email.eq.user@example.com,id.eq.val"
                     const parts = f.val.split(',');
                     const orClauses = parts.map(part => {
                         const match = part.match(/^([^.]+)\.([^.]+)\.(.*)$/);
                         if (match) {
                             const [, col, op, val] = match;
                             if (op === 'eq') {
                                 values.push(val);
                                 return `"${col}" = $${valIndex++}`;
                             }
                         }
                         return 'FALSE';
                     });
                     clauses.push(`(${orClauses.join(' OR ')})`);
                 }
              });
              if (clauses.length > 0) sql += ' WHERE ' + clauses.join(' AND ');
          }

          if (query.order && query.order.length > 0) {
              const orderClauses = query.order.map(o => `"${o.col}" ${o.ascending ? 'ASC' : 'DESC'}`);
              sql += ' ORDER BY ' + orderClauses.join(', ');
          }

          if (query.options && query.options.limit) {
              sql += ` LIMIT ${parseInt(query.options.limit)}`;
          }
      }
    } 
    else if (action === 'insert') {
        const columns = Object.keys(payload[0]);
        const placeholders = [];
        payload.forEach((row) => {
            const rowPlaces = [];
            columns.forEach(col => { rowPlaces.push(`$${valIndex++}`); values.push(row[col]); });
            placeholders.push(`(${rowPlaces.join(', ')})`);
        });
        sql = `INSERT INTO ${table} ("${columns.join('", "')}") VALUES ${placeholders.join(', ')} RETURNING *`;
    }
    else if (action === 'update') {
        const columns = Object.keys(payload);
        const setClauses = [];
        columns.forEach(col => {
            setClauses.push(`"${col}" = $${valIndex++}`); values.push(payload[col]);
        });
        sql = `UPDATE ${table} SET ${setClauses.join(', ')}`;
        if (query.filters && query.filters.length > 0) {
              const clauses = [];
              query.filters.forEach(f => {
                 if (f.type === 'eq') {
                     clauses.push(`"${f.col}" = $${valIndex++}`); values.push(f.val);
                 }
              });
              if (clauses.length > 0) sql += ' WHERE ' + clauses.join(' AND ');
        }
        sql += ' RETURNING *';
    }
    else if (action === 'upsert') {
         if (table === 'employee_subtheme_alignment') {
            for (let record of payload) {
              await pool.query(
                `INSERT INTO employee_subtheme_alignment (employee_id, subtheme_id, cycle_year, status) 
                 VALUES ($1, $2, $3, $4) 
                 ON CONFLICT (employee_id, subtheme_id, cycle_year) 
                 DO UPDATE SET status = EXCLUDED.status`,
                [record.employee_id, record.subtheme_id, record.cycle_year, record.status]
              );
            }
            return res.json({ data: payload, error: null });
         } else if (table === 'monthly_reviews') {
            const columns = Object.keys(payload[0]);
            const placeholders = columns.map((_, i) => `$${i + 1}`).join(', ');
            const updateClauses = columns.filter(c => c !== 'employee_id' && c !== 'cycle_id').map(c => `"${c}" = EXCLUDED."${c}"`).join(', ');
            
            for (let record of payload) {
              const values = columns.map(c => record[c]);
              await pool.query(
                `INSERT INTO monthly_reviews ("${columns.join('", "')}") 
                 VALUES (${placeholders}) 
                 ON CONFLICT (employee_id, cycle_id) 
                 DO UPDATE SET ${updateClauses}`,
                values
              );
            }
            return res.json({ data: payload, error: null });
         } else {
            // Generic upsert for tables with 'id' as primary key
            const columns = Object.keys(payload[0]);
            const placeholders = columns.map((_, i) => `$${i + 1}`).join(', ');
            const updateClauses = columns.filter(c => c !== 'id').map(c => `"${c}" = EXCLUDED."${c}"`).join(', ');
            
            for (let record of payload) {
              const values = columns.map(c => record[c]);
              await pool.query(
                `INSERT INTO ${table} ("${columns.join('", "')}") 
                 VALUES (${placeholders}) 
                 ON CONFLICT (id) 
                 DO UPDATE SET ${updateClauses}`,
                values
              );
            }
            return res.json({ data: payload, error: null });
         }
    }

    if (sql) {
        const { rows } = await pool.query(sql, values);
        let data = rows;
        let count = null;
        
        if (query.select && typeof query.select === 'object' && query.select.count) {
            count = rows.length; // Approximate count for mock
        }

        if (query.options && query.options.single) {
            data = rows.length > 0 ? rows[0] : null;
        }
        
        if (query.options && query.options.head) {
            data = null;
        }

        return res.json({ data, count, error: null });
    } else {
        return res.json({ data: null, error: 'Unhandled query type' });
    }
  } catch (error) {
    res.status(500).json({ data: null, error: error.message });
  }
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`Pure Postgres Backend server running on http://localhost:${PORT}`);
});
