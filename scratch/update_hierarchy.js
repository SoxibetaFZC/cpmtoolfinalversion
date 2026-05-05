import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://jmnjguadgmdyxfrmecpn.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImptbmpndWFkZ21keXhmcm1lY3BuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU5MDg1MDMsImV4cCI6MjA5MTQ4NDUwM30.JJdJgW_N922_aotLraP0ib4BUY7Pr5ucZnJgXF6-XFs';

const supabase = createClient(supabaseUrl, supabaseKey);

async function reassign() {
  // 1. Get Manager UUIDs
  const { data: managers } = await supabase.from('profiles').select('id, employee_id').in('employee_id', ['EMP-002', 'EMP-003']);
  const managerMap = {};
  managers.forEach(m => managerMap[m.employee_id] = m.id);

  console.log("Managers found:", managerMap);

  if (!managerMap['EMP-002'] || !managerMap['EMP-003']) {
    console.error("Could not find manager UUIDs!");
    return;
  }

  // 2. Prepare employee IDs
  const group1 = Array.from({length: 8}, (_, i) => `EMP-${205 + i}`);
  const group2 = Array.from({length: 8}, (_, i) => `EMP-${213 + i}`);

  console.log("Reassigning Group 1:", group1);
  console.log("Reassigning Group 2:", group2);

  // 3. Perform Updates
  const { error: err1 } = await supabase.from('profiles').update({ manager_id: managerMap['EMP-002'] }).in('employee_id', group1);
  const { error: err2 } = await supabase.from('profiles').update({ manager_id: managerMap['EMP-003'] }).in('employee_id', group2);

  if (err1 || err2) {
    console.error("Error updating hierarchy:", err1 || err2);
  } else {
    console.log("✅ Success! Organizational hierarchy updated for 16 employees.");
  }
}

reassign();
