shader_type canvas_item;
// Sobreposicao de alucinacao.
//
// Deliberadamente NAO le a textura da tela (SCREEN_TEXTURE): efeitos que
// dependem de back buffer se comportam de forma diferente entre o renderer
// Compatibility e o Forward+, e quebram com facilidade no export para web.
// Aqui tudo e gerado por procedimento e composto por cima -- roda igual em
// todo lugar, inclusive no navegador.
//
// Regra de ouro deste shader: ele nunca pode atrapalhar a leitura do combate.
// Se voce aumentar qualquer numero aqui, teste jogando a onda 4 antes de
// commitar -- e muito facil deixar bonito e injogavel.

uniform float intensidade : hint_range(0.0, 1.0) = 0.0;
uniform vec4 cor_glitch : source_color = vec4(1.0, 0.15, 0.42, 1.0);
uniform vec4 cor_vinheta : source_color = vec4(0.55, 0.0, 0.25, 1.0);
// Teto duro de opacidade. Existe para impedir que alguem transforme o efeito
// numa cortina.
uniform float alpha_maximo : hint_range(0.0, 1.0) = 0.5;

float ruido(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	float alpha = 0.0;
	vec3 cor = vec3(0.0);

	// --- Vinheta: fecha o campo de visao conforme a mente degrada ---
	float d = distance(uv, vec2(0.5));
	float vinheta = smoothstep(0.38, 0.82, d) * (0.14 + intensidade * 0.44);
	cor += cor_vinheta.rgb * vinheta;
	alpha = max(alpha, vinheta);

	// --- Faixas horizontais que "escorregam" ---
	// Raras de proposito: um flash ocasional assusta, um padrao constante cega.
	float faixa = floor(uv.y * 60.0);
	float gatilho = step(0.975 - intensidade * 0.045, ruido(vec2(faixa, floor(t * 9.0))));
	float banda = gatilho * intensidade * 0.55;
	cor += cor_glitch.rgb * banda * 0.35;
	alpha = max(alpha, banda * 0.22);

	// --- Scanlines ---
	float scan = sin(uv.y * 900.0) * 0.5 + 0.5;
	float peso_scan = scan * intensidade * 0.045;
	cor += cor_glitch.rgb * peso_scan;
	alpha = max(alpha, peso_scan);

	// --- Chiado ---
	float n = ruido(uv * 620.0 + vec2(t * 37.0, t * 23.0));
	float chiado = step(0.994 - intensidade * 0.02, n) * intensidade * 0.22;
	cor += vec3(chiado);
	alpha = max(alpha, chiado);

	// --- Pulso de batimento quando esta critico (so nas bordas) ---
	float pulso = max(0.0, sin(t * 2.4)) * max(0.0, intensidade - 0.7) * 0.5;
	cor += cor_glitch.rgb * pulso * vinheta * 2.0;
	alpha = max(alpha, pulso * vinheta);

	// --- Brilho leve e contínuo no estado crítico ---
	float brilho_critico = max(0.0, intensidade - 0.8) * 0.25;
	cor += vec3(brilho_critico);
	alpha = max(alpha, brilho_critico);

	COLOR = vec4(cor, clamp(alpha, 0.0, alpha_maximo));
}
