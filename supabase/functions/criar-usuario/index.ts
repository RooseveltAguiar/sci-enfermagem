import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const supabaseServiceRoleKey =
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!supabaseUrl || !supabaseServiceRoleKey) {
      throw new Error("Configuração ausente do servidor Supabase.");
    }

    // 1. Validar autenticação do chamador
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Não autenticado." }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const {
      data: { user: callingUser },
      error: authError,
    } = await supabaseClient.auth.getUser();

    if (authError || !callingUser) {
      return new Response(
        JSON.stringify({ error: "Não autenticado ou sessão inválida." }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Cliente admin com service_role para checar perfil e executar fluxo
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey);

    // Verificar se o chamador é coordenação (ator_4)
    const { data: callerProfile, error: profileError } = await supabaseAdmin
      .from("usuarios")
      .select("perfil")
      .eq("id", callingUser.id)
      .single();

    if (profileError || !callerProfile || callerProfile.perfil !== "coordenacao") {
      return new Response(
        JSON.stringify({
          error: "Acesso negado. Apenas a Coordenação pode gerenciar usuários.",
        }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Extrair parâmetros do request
    const { cpf, nome, perfil, email } = await req.json();

    if (!cpf || !nome || !perfil) {
      return new Response(
        JSON.stringify({ error: "Parâmetros obrigatórios ausentes: cpf, nome, perfil." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const cpfDigits = String(cpf).replace(/\D/g, "");
    if (cpfDigits.length !== 11) {
      return new Response(
        JSON.stringify({ error: "CPF inválido." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const emailFinal =
      email && String(email).trim().length > 0
        ? String(email).trim()
        : `${cpfDigits}@sci.uece.br`;

    // 3. Gerar senha temporária automaticamente
    const tempPassword = crypto.randomUUID().slice(0, 8);

    // 4. Criar usuário no GoTrue (etapa 1 atômica)
    const { data: createdUserData, error: createError } =
      await supabaseAdmin.auth.admin.createUser({
        email: emailFinal,
        password: tempPassword,
        email_confirm: true,
      });

    if (createError || !createdUserData?.user) {
      return new Response(
        JSON.stringify({
          error: createError?.message || "Falha ao criar usuário no Auth.",
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const newUserId = createdUserData.user.id;

    // 5. Chamar fn_criar_perfil_usuario (etapa 2 atômica com rollback)
    const { error: rpcError } = await supabaseAdmin.rpc("fn_criar_perfil_usuario", {
      p_id: newUserId,
      p_cpf: cpfDigits,
      p_nome: nome,
      p_perfil: perfil,
      p_email: emailFinal,
    });

    if (rpcError) {
      // ROLLBACK atômico no GoTrue
      await supabaseAdmin.auth.admin.deleteUser(newUserId);
      return new Response(
        JSON.stringify({
          error: `Falha ao criar perfil do usuário: ${rpcError.message}. Criação abortada.`,
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        id: newUserId,
        senha_temporaria: tempPassword,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err?.message || "Erro interno no servidor." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
