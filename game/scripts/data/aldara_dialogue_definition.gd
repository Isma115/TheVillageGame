extends DialogueDefinition
class_name AldaraDialogueDefinition

var _choice_sequence := 0


func _init() -> void:
	id = &"aldara_cartographer"
	speaker_name = "Aldara"
	speaker_title = "Cartógrafa de la aldea"
	start_node_id = &"saludo"
	_build_dialogue()


func _build_dialogue() -> void:
	clear_nodes()
	_choice_sequence = 0

	_add_choice_node(
		&"saludo",
		"Ah, una cara nueva frente a mi puerta. Soy Aldara. Dibujo caminos para que "
		+ "la gente vuelva a casa, aunque últimamente hay un sendero que no quiere "
		+ "quedarse quieto sobre el papel.",
		[
			["¿Quién eres exactamente?", &"presentacion"],
			["Háblame de esta aldea.", &"aldea"],
			["Parece que necesitas ayuda.", &"encargo"],
			["Solo pasaba a saludar.", &"fin_cordial"]
		]
	)
	_add_choice_node(
		&"presentacion",
		"Cartógrafa, archivera y, cuando nadie más quiere hacerlo, mediadora de "
		+ "disputas sobre lindes. Conozco cada tejado y casi todos los secretos "
		+ "que se esconden debajo.",
		[
			["¿Qué mapas estás preparando?", &"mapas"],
			["¿Tu familia vive contigo?", &"familia"],
			["¿Cómo sabías que yo era nuevo?", &"reputacion"],
			["Encantado, Aldara. Volveré otro día.", &"fin_respetuoso"]
		]
	)
	_add_choice_node(
		&"aldea",
		"Pradera parece pequeña desde la colina, pero cada rincón tiene su carácter. "
		+ "Las casas guardan oficios, la plaza guarda promesas y el bosque guarda "
		+ "todo lo que preferimos olvidar.",
		[
			["Cuéntame algo sobre las casas.", &"casas"],
			["¿Qué ocurre normalmente en la plaza?", &"plaza"],
			["¿Qué debería saber de la mina?", &"mina"],
			["¿Y del bosque que rodea el pueblo?", &"bosque"]
		]
	)
	_add_choice_node(
		&"encargo",
		"Anoche desapareció la campana de los caminos. Es pequeña, de cobre, y su "
		+ "sonido guía a quien se pierde entre la niebla. Sin ella, el próximo "
		+ "viajero podría no encontrar la aldea.",
		[
			["Explícame qué pasó con la campana.", &"campana"],
			["Antes de aceptar, ¿hay recompensa?", &"recompensa"],
			["¿Qué peligros encontraría al buscarla?", &"peligro"],
			["No quiero meterme en problemas ajenos.", &"fin_indiferente"]
		]
	)
	_add_choice_node(
		&"mapas",
		"Estoy corrigiendo el plano de la mina y trazando una ruta segura por el "
		+ "bosque. La tinta dice una cosa, las huellas otra. Cuando discrepan, "
		+ "conviene creer a las huellas.",
		[
			["Enséñame el plano de la mina.", &"mina"],
			["¿Dónde empieza ese sendero cambiante?", &"sendero"],
			["¿Puedes enseñarme a orientarme?", &"brujula"],
			["¿Por qué elegiste este oficio?", &"pasado"]
		]
	)
	_add_choice_node(
		&"casas",
		"La casa crema pertenece a una familia de panaderos; la de piedra conserva "
		+ "el archivo antiguo. Esta casa de madera la levantó Silvio, el carpintero. "
		+ "Cada fachada cuenta una parte de la historia.",
		[
			["¿Quién vive en la casa crema?", &"familia"],
			["Quiero saber más sobre Silvio.", &"carpintero"],
			["¿Qué guarda el archivo de piedra?", &"historia"],
			["He visto marcas sobre algunas puertas.", &"simbolos"]
		]
	)
	_add_choice_node(
		&"plaza",
		"Por la mañana hay trueque; al mediodía, noticias; al anochecer, música. "
		+ "La piedra central marca el lugar donde se fundó Pradera, o eso sostiene "
		+ "la versión más amable de la historia.",
		[
			["¿Cuál es la versión menos amable?", &"historia"],
			["¿Qué sucede en la plaza por la noche?", &"rumor"],
			["¿Puedo comerciar allí?", &"comercio"],
			["Prefiero una visión general de la aldea.", &"aldea"]
		]
	)
	_add_choice_node(
		&"mina",
		"La mina es más vieja que las casas. Tiene vetas útiles y ecos traicioneros. "
		+ "Si bajas, marca cada cruce y no confundas el brillo del mineral con una "
		+ "salida.",
		[
			["¿Qué minerales merece la pena buscar?", &"fin_mina_sabia"],
			["¿Se producen derrumbes?", &"peligro"],
			["Alguien mencionó voces bajo tierra.", &"rumor"],
			["Podríamos explorarla juntos.", &"fin_alianza"]
		]
	)
	_add_choice_node(
		&"bosque",
		"El bosque da madera, alimento y refugio, pero exige atención. Los animales "
		+ "avisan antes que los mapas cuando algo cambia. Si todos callan a la vez, "
		+ "detente y escucha.",
		[
			["¿Qué árboles debería reconocer?", &"fin_bosque_arboles"],
			["¿Qué animales pueden ser peligrosos?", &"fin_bosque_animales"],
			["¿Cómo evito perderme entre los árboles?", &"sendero"],
			["Quizá el bosque esté relacionado con tu encargo.", &"encargo"]
		]
	)
	_add_choice_node(
		&"campana",
		"La encontré ausente al amanecer. Había barro oscuro en el soporte y tres "
		+ "plumas grises orientadas hacia el norte. Nadie admite haber oído nada, "
		+ "lo cual en esta aldea significa que muchos oyeron demasiado.",
		[
			["¿Dónde termina el rastro de barro?", &"sendero"],
			["¿A quién crees que debo preguntar?", &"rumor"],
			["¿Por qué es tan importante esa campana?", &"historia"],
			["Acepto buscarla. Planeemos la salida.", &"preparativos"]
		]
	)
	_add_choice_node(
		&"recompensa",
		"Puedo ofrecer monedas, un mapa que no vendo a nadie o un favor personal. "
		+ "También puedes hacerlo sin recompensa y dejarme con una deuda difícil "
		+ "de olvidar.",
		[
			["Prefiero una paga en monedas.", &"comercio"],
			["Quiero el mapa y una lección para leerlo.", &"brujula"],
			["Me guardaré ese favor para más adelante.", &"confianza_alta"],
			["Ayudaré sin cobrar nada.", &"preparativos"]
		]
	)
	_add_choice_node(
		&"peligro",
		"Hay jabalíes si te apartas del camino, piedra suelta cerca de la mina y "
		+ "niebla al caer la tarde. El mayor peligro, sin embargo, es avanzar "
		+ "convencido de que ya entiendes el lugar.",
		[
			["¿Cómo reacciono si aparece un jabalí?", &"fin_bosque_animales"],
			["¿Cómo reconozco una galería inestable?", &"fin_mina_sabia"],
			["Admito que eso me inquieta.", &"confianza_alta"],
			["Iré de todos modos; preparemos el viaje.", &"preparativos"]
		]
	)
	_add_choice_node(
		&"sendero",
		"Parte detrás de la casa de piedra, cruza dos robles juntos y desciende "
		+ "hacia un arroyo seco. Desde allí cambia. Puedes seguir el musgo, las "
		+ "aves o tu instinto; los tres discrepan.",
		[
			["Dame referencias más precisas.", &"brujula"],
			["Seguiré el vuelo de los pájaros.", &"fin_bosque_animales"],
			["Buscaré un atajo desde la mina.", &"fin_mina_sabia"],
			["Ya tengo suficiente. Organicemos la búsqueda.", &"preparativos"]
		]
	)
	_add_choice_node(
		&"brujula",
		"Una brújula ayuda, pero no piensa por ti. Mira el sol, la humedad de la "
		+ "corteza y la pendiente. Después compara las tres señales. Un buen "
		+ "viajero duda con método.",
		[
			["Enséñame a leer la corteza de los árboles.", &"fin_bosque_arboles"],
			["¿Las marcas de las puertas sirven para orientarse?", &"simbolos"],
			["Practicaré durante la búsqueda.", &"preparativos"],
			["No necesito tantas precauciones.", &"confianza_baja"]
		]
	)
	_add_choice_node(
		&"pasado",
		"Aprendí de una maestra que dibujaba de memoria. Un invierno salió a "
		+ "comprobar una ruta y no regresó. Desde entonces verifico cada línea dos "
		+ "veces y nunca dejo una pregunta sin anotar.",
		[
			["¿Era alguien de tu familia?", &"familia"],
			["¿Crees que su desaparición está ligada al rumor?", &"rumor"],
			["¿Por qué decidiste quedarte aquí?", &"historia"],
			["Gracias por confiarme algo tan personal.", &"confianza_alta"]
		]
	)
	_add_choice_node(
		&"familia",
		"Mi hermano Silvio construyó esta casa y luego marchó a vender muebles por "
		+ "los pueblos del sur. Los panaderos de la casa crema son primos nuestros. "
		+ "En Pradera, familia y vecindad casi significan lo mismo.",
		[
			["¿Silvio es el carpintero del que hablabas?", &"carpintero"],
			["¿Su marcha tiene relación con tu pasado?", &"pasado"],
			["¿Podría llevarle una carta si lo encuentro?", &"comercio"],
			["No quiero entrometerme más.", &"confianza_alta"]
		]
	)
	_add_choice_node(
		&"simbolos",
		"Son marcas de orientación: círculo para refugio, triángulo para riesgo y "
		+ "dos líneas para agua. La campana tiene los tres símbolos, porque guía, "
		+ "advierte y recuerda dónde está el arroyo.",
		[
			["¿Quién decidió el significado de cada marca?", &"historia"],
			["Entonces la campana funciona como un mapa.", &"campana"],
			["Quiero aprender a dibujar esos símbolos.", &"mapas"],
			["Parecen supersticiones sin utilidad.", &"confianza_baja"]
		]
	)
	_add_choice_node(
		&"reputacion",
		"Los pájaros se alzaron cuando llegaste y los comerciantes preguntaron por "
		+ "una persona con tus señas. No es magia: solo observo. Tu reputación "
		+ "empieza antes de que pronuncies tu nombre.",
		[
			["Espero haber causado una buena impresión.", &"confianza_alta"],
			["Eso suena demasiado parecido a espiarme.", &"confianza_baja"],
			["¿Cómo puedo ganarme la confianza de la aldea?", &"encargo"],
			["No me preocupa lo que piense la gente.", &"fin_indiferente"]
		]
	)
	_add_choice_node(
		&"confianza_baja",
		"Hablar con seguridad no vuelve cierta una idea. Si quieres que comparta "
		+ "mis rutas contigo, demuestra que sabes escuchar o acepta que algunas "
		+ "puertas permanezcan cerradas.",
		[
			["Tienes razón; he hablado sin pensar.", &"confianza_alta"],
			["Dame una oportunidad para demostrarlo.", &"encargo"],
			["Entonces no tenemos nada más que hablar.", &"fin_frio"],
			["Prefiero comprobar por mi cuenta los rumores.", &"rumor"]
		]
	)
	_add_choice_node(
		&"confianza_alta",
		"Me alegra oírlo. La prudencia compartida pesa menos. Te contaré algo que "
		+ "no figura en ningún mapa: alguien ha hecho sonar la campana desde el "
		+ "bosque durante tres noches, incluso después de su desaparición.",
		[
			["Cuéntame todo lo que sabes de ese sonido.", &"rumor"],
			["Puedes contar conmigo como amiga.", &"fin_amistad"],
			["Prometo ayudarte a recuperar la campana.", &"preparativos"],
			["Primero quiero comprender mejor el bosque.", &"bosque"]
		]
	)
	_add_choice_node(
		&"carpintero",
		"Silvio sabe leer la veta de la madera como yo leo caminos. Construyó "
		+ "puentes, puertas y el soporte vacío de la campana. Si alguien conoce "
		+ "un compartimento oculto, sería él.",
		[
			["¿Dónde puedo encontrar a Silvio?", &"comercio"],
			["¿También construyó las otras casas?", &"casas"],
			["¿Por qué se marchó sin despedirse?", &"familia"],
			["Si lo encuentro, le pediré que vuelva.", &"fin_recado"]
		]
	)
	_add_choice_node(
		&"historia",
		"Los fundadores siguieron el sonido de una campana hasta este claro. Unos "
		+ "dicen que la llevaba una niña; otros, que colgaba del cuello de un "
		+ "ciervo. En el archivo, ambas versiones están escritas con la misma tinta.",
		[
			["¿Es la misma campana que ha desaparecido?", &"campana"],
			["¿De ahí proceden las marcas de orientación?", &"simbolos"],
			["¿Cuál de las dos versiones crees verdadera?", &"rumor"],
			["Esa historia debería quedar en un mapa.", &"mapas"]
		]
	)
	_add_choice_node(
		&"rumor",
		"Se habla de luces entre los robles y de pasos que terminan frente a una "
		+ "pared de roca. Mi teoría es menos emocionante: alguien usa las historias "
		+ "viejas para esconder una ruta nueva.",
		[
			["Seguiré el sonido esta misma noche.", &"preparativos"],
			["¿Y si los animales intentan advertirnos?", &"fin_bosque_animales"],
			["¿Quién ganaría ocultando una ruta?", &"comercio"],
			["Guardaré tu teoría en secreto.", &"fin_secreto"]
		]
	)
	_add_choice_node(
		&"comercio",
		"Los mercaderes compran madera y mineral, pero la información es la moneda "
		+ "más cara. Silvio viajó con la última caravana. También vendieron una "
		+ "caja de cobre cuyo peso nadie supo explicar.",
		[
			["Seguiré la pista de la caravana y de Silvio.", &"carpintero"],
			["¿La recompensa cubriría comprar esa caja?", &"recompensa"],
			["La caja podría estar relacionada con los rumores.", &"rumor"],
			["Negociaré con los mercaderes antes de partir.", &"fin_negocio"]
		]
	)
	_add_choice_node(
		&"preparativos",
		"Lleva agua, una cuerda y algo con lo que marcar el camino. Podemos buscar "
		+ "la campana, estudiar la ruta o hablar con quienes ocultan información. "
		+ "La decisión inicial cambiará lo que encontremos después.",
		[
			["Iré directo a recuperar la campana.", &"fin_campana"],
			["Primero cartografiaré el sendero cambiante.", &"fin_rastreador"],
			["Hablaré con la gente antes de acusar a nadie.", &"fin_mediador"],
			["Necesito tiempo; volveré cuando esté listo.", &"fin_posponer"]
		]
	)

	_add_terminal(
		&"fin_cordial",
		"Un saludo también puede ser el inicio de una ruta. Cuando quieras hablar, "
		+ "me encontrarás aquí, junto a la casa de madera."
	)
	_add_terminal(
		&"fin_respetuoso",
		"El gusto es mío. Que tus pasos sean firmes y tus regresos sencillos."
	)
	_add_terminal(
		&"fin_indiferente",
		"Lo comprendo. Ningún mapa obliga a tomar un camino, pero todo camino acaba "
		+ "teniendo consecuencias."
	)
	_add_terminal(
		&"fin_mina_sabia",
		"El carbón y el hierro abundan; cobre, plata y oro exigen paciencia. Golpea "
		+ "solo vetas firmes y abandona una galería si cae polvo del techo."
	)
	_add_terminal(
		&"fin_alianza",
		"Quizá acepte cuando recupere la campana. No me disgustaría volver a la mina "
		+ "con alguien que sabe formular una invitación."
	)
	_add_terminal(
		&"fin_bosque_arboles",
		"El roble tiene copa ancha, el pino apunta al cielo y el abedul luce corteza "
		+ "clara. Toma solo la madera que necesites y deja espacio para que el bosque "
		+ "se reponga."
	)
	_add_terminal(
		&"fin_bosque_animales",
		"Los ciervos y conejos huirán; los pájaros delatan cambios; el jabalí puede "
		+ "embestir si lo acorralas. Dale espacio y nunca te interpongas entre una "
		+ "cría y su madre."
	)
	_add_terminal(
		&"fin_frio",
		"Entonces termina aquí nuestra conversación. La puerta seguirá en su sitio; "
		+ "no puedo prometer lo mismo de mi confianza."
	)
	_add_terminal(
		&"fin_amistad",
		"Amiga es una palabra grande. La aceptaré como promesa y te ofreceré la "
		+ "misma a cambio. Vuelve sana, con campana o sin ella."
	)
	_add_terminal(
		&"fin_recado",
		"Dile que su hermana aún guarda la lámpara encendida. Si eso no lo hace "
		+ "volver, al menos sabrá que esta casa continúa siendo suya."
	)
	_add_terminal(
		&"fin_secreto",
		"Gracias. Un secreto bien guardado no desaparece: espera hasta que llega el "
		+ "momento adecuado para convertirse en verdad."
	)
	_add_terminal(
		&"fin_negocio",
		"Buena elección. Escucha el primer precio, pregunta por el segundo y no "
		+ "enseñes cuánto te interesa la caja de cobre."
	)
	_add_terminal(
		&"fin_campana",
		"Entonces tu ruta será la más directa y quizá la más peligrosa. Busca barro "
		+ "oscuro y plumas grises. Si oyes la campana, no corras: cuenta tres ecos."
	)
	_add_terminal(
		&"fin_rastreador",
		"Te prestaré mi cuaderno de campo. Registra cada giro, incluso los que "
		+ "parezcan imposibles. A veces el error repetido es la pista más valiosa."
	)
	_add_terminal(
		&"fin_mediador",
		"Empieza por los mercaderes y termina con Silvio si logras encontrarlo. "
		+ "Escuchar versiones contradictorias puede revelar el único detalle cierto."
	)
	_add_terminal(
		&"fin_posponer",
		"La prudencia también consiste en saber cuándo esperar. La campana no dejará "
		+ "de estar perdida porque te prepares bien. Vuelve cuando decidas tu ruta."
	)


func _add_choice_node(
	node_id: StringName,
	node_text: String,
	choice_specs: Array
) -> void:
	var node_choices: Array[DialogueChoice] = []
	for spec_value in choice_specs:
		var spec := spec_value as Array
		if spec == null or spec.size() != 2:
			continue
		_choice_sequence += 1
		var choice := DialogueChoice.new()
		choice.configure(
			StringName("aldara_choice_%03d" % _choice_sequence),
			str(spec[0]),
			StringName(spec[1])
		)
		node_choices.append(choice)

	var node := DialogueNode.new()
	add_node(node.configure(node_id, node_text, node_choices))


func _add_terminal(node_id: StringName, node_text: String) -> void:
	var terminal := DialogueNode.new()
	add_node(terminal.configure(node_id, node_text))
