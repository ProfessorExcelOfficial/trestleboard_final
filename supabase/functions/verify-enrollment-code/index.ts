import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import bcrypt from "https://esm.sh/bcryptjs";

Deno.serve(async (req) => {
  try {

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const body = await req.json();

    const email = body.email?.toLowerCase().trim();
    const code = body.code?.toUpperCase().trim();

    if (!email || !code) {
      return new Response(
        JSON.stringify({ error: "email and code required" }),
        { status: 400 }
      );
    }

    // --------------------------------------------------
    // Load active enrollment codes for this email
    // --------------------------------------------------

    const { data: codes, error } = await supabaseAdmin
      .from("enrollment_codes")
      .select(`
        id,
        code_hash,
        expires_at,
        used_at,
        revoked,
        attempt_count,
        max_attempts,
        member_id,
        members!inner(email)
      `)
      .eq("members.email", email)
      .is("used_at", null)
      .eq("revoked", false);

    if (error) throw error;

    if (!codes || codes.length === 0) {
      return new Response(
        JSON.stringify({ error: "Invalid enrollment code" }),
        { status: 400 }
      );
    }

    // --------------------------------------------------
    // Find matching code using bcrypt
    // --------------------------------------------------

    let matchedCode: any = null;

    for (const c of codes) {

      if (c.attempt_count >= c.max_attempts) {
        continue;
      }

      const match = await bcrypt.compare(code, c.code_hash);

      if (match) {
        matchedCode = c;
        break;
      }
    }

    if (!matchedCode) {

      // increment attempts
      for (const c of codes) {
        await supabaseAdmin
          .from("enrollment_codes")
          .update({
            attempt_count: c.attempt_count + 1
          })
          .eq("id", c.id);
      }

      return new Response(
        JSON.stringify({ error: "Invalid enrollment code" }),
        { status: 400 }
      );
    }

    // --------------------------------------------------
    // Check expiration
    // --------------------------------------------------

    if (new Date(matchedCode.expires_at) < new Date()) {
      return new Response(
        JSON.stringify({ error: "Code expired" }),
        { status: 400 }
      );
    }

    // --------------------------------------------------
    // Find member if exists
    // --------------------------------------------------

    let memberId = matchedCode.member_id;

    if (!memberId) {
      const { data: member } = await supabaseAdmin
        .from("members")
        .select("id")
        .eq("email", email)
        .maybeSingle();

      if (member) {
        memberId = member.id;
      }
    }

    // --------------------------------------------------
    // Mark code used
    // --------------------------------------------------

    await supabaseAdmin
      .from("enrollment_codes")
      .update({
        used_at: new Date().toISOString(),
        member_id: memberId
      })
      .eq("id", matchedCode.id);


    // --------------------------------------------------
// Check if auth user already exists
// --------------------------------------------------

let userId: string | null = null;

const { data: existingUsers } = await supabaseAdmin.auth.admin.listUsers();

const existing = existingUsers?.users.find(
  (u) => u.email?.toLowerCase() === email
);

if (existing) {

  // user already exists
  userId = existing.id;

} else {

  // create new auth user
  const { data: authUser, error: authError } =
    await supabaseAdmin.auth.admin.createUser({
      email: email,
      email_confirm: true
    });

  if (authError) throw authError;

  userId = authUser.user.id;
}

    // --------------------------------------------------
    // Link member record to auth account
    // --------------------------------------------------

    if (memberId) {
      await supabaseAdmin
        .from("members")
        .update({
          user_id: userId
        })
        .eq("id", memberId);
    }

    // --------------------------------------------------
    // Success
    // --------------------------------------------------

    return new Response(
      JSON.stringify({
        success: true
      }),
      { status: 200 }
    );

  } catch (err) {

    console.error("VERIFY ERROR:", err);

    return new Response(
      JSON.stringify({
        error: err instanceof Error ? err.message : "Unexpected error"
      }),
      { status: 500 }
    );
  }
});