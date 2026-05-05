const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabase = createClient(process.env.VITE_SUPABASE_URL, process.env.VITE_SUPABASE_ANON_KEY);

async function updateHierarchy() {
  const hodId = '00000000-0000-0000-0000-000000000001'; // EMP001 (Alexander Vance, HOD)
  const employeeIds = [
    '00000000-0000-0000-0000-000000000005', // EMP005
    'f4590e94-7e56-4a6d-b0c3-17892a57694c'  // EMP016
  ];

  console.log(`🚀 Updating hierarchy: Aligning EMP005 and EMP016 under HOD EMP001 (${hodId})...`);

  const { data, error } = await supabase
    .from('profiles')
    .update({ manager_id: hodId })
    .in('id', employeeIds);

  if (error) {
    console.error('❌ Error updating hierarchy:', error);
  } else {
    console.log('✅ Hierarchy updated successfully!');
  }
}

updateHierarchy();
