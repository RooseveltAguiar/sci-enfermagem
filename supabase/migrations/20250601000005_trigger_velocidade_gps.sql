-- ============================================================
-- MIGRATION: 20250601000005_trigger_velocidade_gps.sql
-- DESCRIÇÃO: Avaliação de confiança de GPS por velocidade (Anti-spoofing)
-- ============================================================

CREATE OR REPLACE FUNCTION fn_avaliar_confianca_gps()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Velocidade > 5 m/s (18 km/h) enquanto "a pé"
  -- indica spoofing ou transporte — rebaixa confiança
  IF NEW.velocidade_ms IS NOT NULL
     AND NEW.velocidade_ms > 5 THEN
    NEW.nivel_confianca_gps := LEAST(
      NEW.nivel_confianca_gps, 0.3
    );
    NEW.mock_location_detectado := true;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_avaliar_confianca_gps ON frequencias;
CREATE TRIGGER trg_avaliar_confianca_gps
BEFORE INSERT ON frequencias
FOR EACH ROW
EXECUTE FUNCTION fn_avaliar_confianca_gps();
