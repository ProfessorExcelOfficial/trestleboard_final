import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  try {
    // -----------------------------
    // Parse Request Body
    // -----------------------------
    const {
      lodge_number,
      lodge_name,
      city,
      province,
      email,
      wm_email,
      wm_password, // kept for compatibility, but not used when inviting
    } = await req.json();

    if (
      !lodge_number ||
      !lodge_name ||
      !city ||
      !province ||
      !wm_email
    ) {
      return new Response(
        JSON.stringify({ error: "Missing required fields" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // -----------------------------
    // Create Supabase Clients
    // -----------------------------
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const supabaseUser = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      {
        global: {
          headers: {
            Authorization: req.headers.get("Authorization") ?? "",
          },
        },
      }
    );

    // -----------------------------
    // Validate JWT
    // -----------------------------
    const {
      data: { user },
      error: authError,
    } = await supabaseUser.auth.getUser();

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Invalid JWT" }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      );
    }

    // -----------------------------
    // Verify Admin Role
    // -----------------------------
    const { data: profile, error: profileError } =
      await supabaseUser
        .from("user_profiles")
        .select("role")
        .eq("id", user.id)
        .single();

    if (profileError || !profile || profile.role !== "Admin") {
      return new Response(
        JSON.stringify({ error: "Not authorized" }),
        { status: 403, headers: { "Content-Type": "application/json" } }
      );
    }

    // -----------------------------
    // Invite WM (Creates User + Sends Email)
    // -----------------------------
    const { data: invitedUser, error: inviteError } =
      await supabaseAdmin.auth.admin.inviteUserByEmail(wm_email);

    if (inviteError || !invitedUser.user) {
      throw new Error(inviteError?.message);
    }

    const wmUserId = invitedUser.user.id;

    // -----------------------------
    // Insert WM Profile
    // -----------------------------
    const { error: profileInsertError } =
      await supabaseAdmin.from("user_profiles").insert({
        id: wmUserId,
        role: "Member",
      });

    if (profileInsertError) {
      throw new Error(profileInsertError.message);
    }

    // -----------------------------
    // Create Lodge via RPC
    // -----------------------------
    const { error: rpcError } =
      await supabaseAdmin.rpc("admin_create_lodge", {
        p_lodge_number: lodge_number,
        p_lodge_name: lodge_name,
        p_city: city,
        p_province: province,
        p_email: email,
        p_wm_user_id: wmUserId,
      });

    if (rpcError) {
      throw new Error(rpcError.message);
    }

    // -----------------------------
    // Success
    // -----------------------------
    return new Response(
      JSON.stringify({
        success: true,
        message:
          "Lodge created. Worshipful Master invitation email has been sent.",
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );

  } catch (err) {
    console.error("FUNCTION ERROR:", err);

    return new Response(
      JSON.stringify({
        error: err instanceof Error ? err.message : "Unexpected error",
      }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});