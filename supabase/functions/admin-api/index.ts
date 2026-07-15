import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
}

serve(async (req) => {
  // Handle CORS preflight options request
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. Extract Authorization JWT header
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing Authorization header' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // 2. Create normal client with user's JWT to verify admin privileges
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    })

    // Get current user details from auth.users
    const { data: { user }, error: userError } = await userClient.auth.getUser()
    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'Invalid user token: ' + userError?.message }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Query profiles to check role & suspension status
    const { data: profile, error: profileError } = await userClient
      .from('profiles')
      .select('role, is_suspended')
      .eq('id', user.id)
      .maybeSingle()

    if (profileError || !profile || profile.role !== 'admin' || profile.is_suspended) {
      return new Response(JSON.stringify({ error: 'Forbidden: Insufficient administrative privileges' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // 3. Create admin client using the service role key to bypass RLS
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const adminClient = createClient(supabaseUrl, supabaseServiceKey)

    // 4. Parse request body
    const body = await req.json()
    const { action, payload } = body

    // 5. Route based on action
    switch (action) {
      case 'get_stats': {
        const thirtyDaysAgo = new Date()
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30)

        const oneDayAgo = new Date()
        oneDayAgo.setDate(oneDayAgo.getDate() - 1)

        const fourteenDaysAgo = new Date()
        fourteenDaysAgo.setDate(fourteenDaysAgo.getDate() - 14)

        const [
          { count: userCount },
          { count: activeUsersCount },
          { count: projectCount },
          { count: clientCount },
          { count: reviewCount },
          { count: commentCount },
          { count: newUsersCount },
          { data: recentActivitiesForDAU },
          { data: recentActivitiesForMAU },
          { data: recentProfiles },
        ] = await Promise.all([
          adminClient.from('profiles').select('*', { count: 'exact', head: true }),
          adminClient.from('profiles').select('*', { count: 'exact', head: true }).eq('is_suspended', false),
          adminClient.from('projects').select('*', { count: 'exact', head: true }),
          adminClient.from('clients').select('*', { count: 'exact', head: true }),
          adminClient.from('reviews').select('*', { count: 'exact', head: true }),
          adminClient.from('comments').select('*', { count: 'exact', head: true }),
          adminClient.from('profiles').select('*', { count: 'exact', head: true }).gte('created_at', thirtyDaysAgo.toISOString()),
          adminClient.from('activities').select('user_id').gte('created_at', oneDayAgo.toISOString()),
          adminClient.from('activities').select('user_id').gte('created_at', thirtyDaysAgo.toISOString()),
          adminClient.from('profiles').select('created_at').gte('created_at', fourteenDaysAgo.toISOString()),
        ])

        const uniqueDAU = new Set((recentActivitiesForDAU || []).map((a: any) => a.user_id)).size
        const uniqueMAU = new Set((recentActivitiesForMAU || []).map((a: any) => a.user_id)).size

        // Calculate daily registrations
        const dailyRegistrations: Record<string, number> = {}
        for (let i = 0; i < 14; i++) {
          const d = new Date()
          d.setDate(d.getDate() - i)
          const dateKey = d.toISOString().split('T')[0]
          dailyRegistrations[dateKey] = 0
        }

        for (const u of (recentProfiles || [])) {
          if (u.created_at) {
            const dateKey = u.created_at.split('T')[0]
            if (dailyRegistrations[dateKey] !== undefined) {
              dailyRegistrations[dateKey]++
            }
          }
        }

        const dailyList = Object.entries(dailyRegistrations).map(([date, count]) => ({
          date,
          count,
        })).sort((a, b) => b.date.localeCompare(a.date))

        // Calculate Storage Used
        let totalStorageBytes = 0
        const { data: buckets } = await adminClient.storage.listBuckets()
        const targetBuckets = buckets?.map(b => b.name) || ['video-reviews', 'voice-comments']
        
        for (const bucketName of targetBuckets) {
          const { data: files } = await adminClient.storage.from(bucketName).list()
          if (files) {
            totalStorageBytes += files.reduce((sum, f) => sum + (f.metadata?.size || 0), 0)
          }
        }

        // Fetch Postgres Database Size (tables, metadata, indexes)
        let dbSize = 0
        try {
          const { data: dbData } = await adminClient.rpc('get_database_size')
          if (dbData) {
            dbSize = Number(dbData)
          }
        } catch (e) {
          console.error('Error fetching database size:', e)
        }

        // Recent activity
        const { data: recentActivity } = await adminClient
          .from('activities')
          .select('*')
          .eq('type', 'admin_log')
          .order('created_at', { ascending: false })
          .limit(15)

        return new Response(JSON.stringify({
          stats: {
            totalUsers: userCount || 0,
            activeUsers: activeUsersCount || 0,
            newUsers: newUsersCount || 0,
            totalProjects: projectCount || 0,
            totalClients: clientCount || 0,
            totalReviews: reviewCount || 0,
            totalComments: commentCount || 0,
            totalStorageUsed: totalStorageBytes + dbSize,
            dau: uniqueDAU,
            mau: uniqueMAU,
            dailyNewUsers: dailyList,
          },
          recentActivity: recentActivity || []
        }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
      }

      case 'get_users': {
        const searchStr = payload?.search || ''
        let query = adminClient
          .from('profiles')
          .select('*')

        if (searchStr) {
          const trimmed = searchStr.trim()
          const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(trimmed)
          if (isUuid) {
            query = query.eq('id', trimmed)
          } else {
            query = query.or(`full_name.ilike.%${trimmed}%,email.ilike.%${trimmed}%`)
          }
        }

        const { data: users, error: fetchErr } = await query.order('created_at', { ascending: false })
        if (fetchErr) throw fetchErr

        // Fetch counts manually to avoid missing foreign key relation cache errors
        const [ { data: projects }, { data: clients } ] = await Promise.all([
          adminClient.from('projects').select('user_id'),
          adminClient.from('clients').select('user_id'),
        ])

        const projectCounts: Record<string, number> = {}
        const clientCounts: Record<string, number> = {}

        for (const p of (projects || [])) {
          projectCounts[p.user_id] = (projectCounts[p.user_id] || 0) + 1
        }
        for (const c of (clients || [])) {
          clientCounts[c.user_id] = (clientCounts[c.user_id] || 0) + 1
        }

        const usersWithCounts = (users || []).map(u => ({
          ...u,
          projects: { count: projectCounts[u.id] || 0 },
          clients: { count: clientCounts[u.id] || 0 },
        }))

        return new Response(JSON.stringify({ users: usersWithCounts }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      case 'user_action': {
        const { targetUserId, userAction, targetRole } = payload
        
        let desc = ''
        if (userAction === 'suspend') {
          const { error } = await adminClient.from('profiles').update({ is_suspended: true }).eq('id', targetUserId)
          if (error) throw error
          desc = `Suspended user account (ID: ${targetUserId})`
        } else if (userAction === 'activate') {
          const { error } = await adminClient.from('profiles').update({ is_suspended: false }).eq('id', targetUserId)
          if (error) throw error
          desc = `Activated user account (ID: ${targetUserId})`
        } else if (userAction === 'change_role') {
          const { error } = await adminClient.from('profiles').update({ role: targetRole }).eq('id', targetUserId)
          if (error) throw error
          desc = `Changed role of user (ID: ${targetUserId}) to ${targetRole}`
        } else if (userAction === 'delete') {
          const { error } = await adminClient.auth.admin.deleteUser(targetUserId)
          if (error) throw error
          desc = `Deleted user account (ID: ${targetUserId})`
        }

        // Insert audit log
        if (desc) {
          await adminClient.from('activities').insert({
            user_id: user?.id,
            type: 'admin_log',
            description: desc,
          })
        }

        return new Response(JSON.stringify({ success: true }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      case 'get_projects': {
        const { data: projects, error } = await adminClient
          .from('projects')
          .select('*, clients(name, company)')
          .order('created_at', { ascending: false })
        if (error) throw error

        const { data: profiles, error: profError } = await adminClient
          .from('profiles')
          .select('id, full_name, email')
        if (profError) throw profError

        const profileMap: Record<string, { full_name: string; email: string }> = {}
        for (const p of (profiles || [])) {
          profileMap[p.id] = { full_name: p.full_name, email: p.email }
        }

        const projectsWithProfiles = (projects || []).map(p => ({
          ...p,
          profiles: profileMap[p.user_id] || { full_name: 'None', email: '' }
        }))

        return new Response(JSON.stringify({ projects: projectsWithProfiles }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      case 'get_storage': {
        let totalStorageBytes = 0
        const filesList: any[] = []
        const userUsage: { [key: string]: number } = {}

        const { data: buckets } = await adminClient.storage.listBuckets()
        const targetBuckets = buckets?.map(b => b.name) || ['video-reviews', 'voice-comments']
        
        for (const bucketName of targetBuckets) {
          const { data: files } = await adminClient.storage.from(bucketName).list()
          if (files) {
            for (const file of files) {
              const size = file.metadata?.size || 0
              totalStorageBytes += size
              filesList.push({
                name: file.name,
                bucket: bucketName,
                sizeBytes: size,
                createdAt: file.created_at,
              })

              const parts = file.name.split('/')
              if (parts.length > 1) {
                const folder = parts[0]
                userUsage[folder] = (userUsage[folder] || 0) + size
              }
            }
          }
        }

        // Fetch Postgres Database Size
        let dbSize = 0
        try {
          const { data: dbData } = await adminClient.rpc('get_database_size')
          if (dbData) {
            dbSize = Number(dbData)
          }
        } catch (e) {
          console.error('Error fetching database size:', e)
        }

        if (dbSize > 0) {
          filesList.push({
            name: "PostgreSQL Database (text, tables & metadata)",
            bucket: "database",
            sizeBytes: dbSize,
            createdAt: new Date().toISOString(),
          })
          userUsage["system_database"] = dbSize
        }

        filesList.sort((a, b) => b.sizeBytes - a.sizeBytes)

        return new Response(JSON.stringify({
          totalStorageUsed: totalStorageBytes + dbSize,
          largestFiles: filesList.slice(0, 20),
          userUsage,
        }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      case 'send_broadcast': {
        const { messageType, title, description, targetType, selectedUserIds } = payload
        let targetUserIds: string[] = []
        
        if (targetType === 'all') {
          const { data: users } = await adminClient.from('profiles').select('id')
          targetUserIds = users?.map(u => u.id) || []
        } else if (targetType === 'admins') {
          const { data: users } = await adminClient.from('profiles').select('id').eq('role', 'admin')
          targetUserIds = users?.map(u => u.id) || []
        } else if (targetType === 'non_admins') {
          const { data: users } = await adminClient.from('profiles').select('id').eq('role', 'user')
          targetUserIds = users?.map(u => u.id) || []
        } else if (targetType === 'selected') {
          targetUserIds = selectedUserIds || []
        }

        if (targetUserIds.length > 0) {
          const inserts = targetUserIds.map(uid => ({
            user_id: uid,
            type: messageType,
            description: `${title}: ${description}`,
          }))

          const { error } = await adminClient.from('activities').insert(inserts)
          if (error) throw error
        }

        // Insert admin audit log
        await adminClient.from('activities').insert({
          user_id: user?.id,
          type: 'admin_log',
          description: `Broadcasted targeted ${messageType} notification: "${title}" to target "${targetType}"`,
        })

        return new Response(JSON.stringify({ success: true, count: targetUserIds.length }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      case 'get_analytics': {
        const { data: projects } = await adminClient.from('projects').select('created_at, status')
        const { data: users } = await adminClient.from('profiles').select('created_at')

        return new Response(JSON.stringify({ projects, users }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      case 'get_settings': {
        const { data: settings, error } = await adminClient.from('system_settings').select('*')
        if (error) throw error
        return new Response(JSON.stringify({ settings }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      case 'update_settings': {
        const { settingsList } = payload
        
        for (const item of settingsList) {
          const { error } = await adminClient
            .from('system_settings')
            .upsert({ key: item.key, value: item.value, updated_at: new Date().toISOString() })
          if (error) throw error
        }

        // Insert admin audit log
        await adminClient.from('activities').insert({
          user_id: user?.id,
          type: 'admin_log',
          description: `Updated global app settings configuration`,
        })

        return new Response(JSON.stringify({ success: true }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      default:
        return new Response(JSON.stringify({ error: 'Unknown action: ' + action }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
    }
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message || error }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
