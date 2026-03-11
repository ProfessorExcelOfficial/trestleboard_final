import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// --------------------------------------------------
// SECURE RANDOM CODE GENERATOR
// --------------------------------------------------
function generateCode(length = 8) {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);

  return Array.from(bytes)
    .map((b) => chars[b % chars.length])
    .join("");
}

// --------------------------------------------------
// HASH CODE (ALWAYS UPPERCASE FOR CONSISTENCY)
// --------------------------------------------------
async function hashCode(code: string) {
  const encoder = new TextEncoder();
  const data = encoder.encode(code.toUpperCase());
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);

  return Array.from(new Uint8Array(hashBuffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

Deno.serve(async (req) => {
  try {
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

    // --------------------------------------------------
    // VALIDATE AUTHENTICATED USER
    // --------------------------------------------------
    const {
      data: { user },
      error: authError,
    } = await supabaseUser.auth.getUser();

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401 }
      );
    }

    // --------------------------------------------------
    // VALIDATE ADMIN ROLE
    // --------------------------------------------------
    const { data: adminCheck, error: adminError } =
      await supabaseAdmin
        .from("system_admins")
        .select("id")
        .eq("user_id", user.id)
        .single();

    if (adminError || !adminCheck) {
      return new Response(
        JSON.stringify({ error: "Forbidden" }),
        { status: 403 }
      );
    }

    // --------------------------------------------------
    // PARSE REQUEST BODY
    // --------------------------------------------------
    const { req_member_id } = await req.json();

    if (!req_member_id) {
      return new Response(
        JSON.stringify({ error: "req_member_id required" }),
        { status: 400 }
      );
    }

    // --------------------------------------------------
    // FETCH MEMBER REQUEST
    // --------------------------------------------------
    const { data: memberRequest, error: memberError } =
      await supabaseAdmin
        .from("req_members")
        .select("*")
        .eq("id", req_member_id)
        .single();

    if (memberError || !memberRequest) {
      return new Response(
        JSON.stringify({ error: "Request not found" }),
        { status: 404 }
      );
    }

    // --------------------------------------------------
    // STATUS MUST BE APPROVED
    // --------------------------------------------------
    if (memberRequest.status !== "APPROVED") {
      return new Response(
        JSON.stringify({
          error: `Invalid status: ${memberRequest.status}. Must be APPROVED to generate code.`,
        }),
        { status: 400 }
      );
    }

    // --------------------------------------------------
    // REVOKE ANY EXISTING UNUSED CODES
    // --------------------------------------------------
    await supabaseAdmin
      .from("enrollment_codes")
      .update({ revoked: true })
      .eq("req_member_id", req_member_id)
      .is("used_at", null)
      .eq("revoked", false);

    // --------------------------------------------------
    // GENERATE NEW ENROLLMENT CODE
    // --------------------------------------------------
    const rawCode = generateCode(8);
    const codeHash = await hashCode(rawCode);

    const expiresAt = new Date(
      Date.now() + 24 * 60 * 60 * 1000
    ).toISOString();

    const { error: insertError } = await supabaseAdmin
      .from("enrollment_codes")
      .insert({
        req_member_id,
        email: memberRequest.email,
        role: memberRequest.role_to_assign,
        code_hash: codeHash,
        expires_at: expiresAt,
        created_by: user.id,
        revoked: false,
      });

    if (insertError) throw insertError;

    // --------------------------------------------------
    // RETURN RAW CODE (ONLY TIME IT IS SHOWN)
    // --------------------------------------------------
    return new Response(
      JSON.stringify({
        success: true,
        enrollment_code: rawCode,
        expires_at: expiresAt,
      }),
      { status: 200 }
    );

  } catch (err) {
    console.error("EDGE ERROR:", err);

    return new Response(
      JSON.stringify({
        error:
          err instanceof Error
            ? err.message
            : "Unexpected error",
      }),
      { status: 500 }
    );
  }
});