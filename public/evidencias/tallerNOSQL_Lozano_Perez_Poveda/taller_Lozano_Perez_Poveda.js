//---------------------------------------------------------------------------------------------
// TALLER MQL
// POR: Sebastian Perez Herrera, Jhonatan Camilo Lozano Buitrago y Einny Camyla Poveda Garcia 
//--------------------------------------------------------------------------------------------

//Parte A

//------------------------------------------------------------------------------------------------
//1. 
// Liste las películas del género Drama estrenadas entre 2000 y 2010 con imdb.rating mayor o igual
// a 8. Proyecte únicamente title, year e imdb.rating (sin _id), ordene por rating descendente, 
// muestre 10 resultados e indique el conteo total.  
//-------------------------------------------------------------------------------------------------
use ('sample_mflix'); 

db.movies.find( 
  {genres: "Drama", year: {$gte: 2000, $lte: 2010}, "imdb.rating": { $gte: 8 } }, 
  {_id: 0, title: 1, year: 1, "imdb.rating": 1} 
).sort({"imdb.rating": -1 }).limit(10);
//conteo 
use ("sample_mflix"); 
db.movies.countDocuments( 
  { genres: "Drama", year: { $gte: 2000, $lte: 2010 }, "imdb.rating": { $gte: 8 }} 
); 

// Filtra las películas de Drama del 2000-2010 con nota IMDb mayor o igual a 8,muestra el 
// top 10 (título, año, rating) y calcula el total de coincidencias.

//------------------------------------------------------------------------------------------------
//2. 
// Liste las peliculas en las que actue Tom Hanks y cuyo director no sea Steven Spielberg.  
//-------------------------------------------------------------------------------------------------
use('sample_mflix'); 

db.movies.find({ 
  $and: [ 
    { cast: "Tom Hanks" }, 
    { directors: {$ne: "Steven Spielberg"} } 
  ] 
}); 

// Busca las peliculas con Tom Hanks pero excluye las peliculas donde Steven Spielberg las dirija , muestra
// tistulo, año, directores y mostrar la cantidad total.

//------------------------------------------------------------------------------------------------
//3. 
// Liste las películas que tengan exactamente 3 géneros y que incluyan Comedy y Romance 
//-------------------------------------------------------------------------------------------------

use('sample_mflix');  

db.movies.find( 
  { genres: { $all: ["Comedy", "Romance"], $size: 3 } }, 
  { _id: 0, title: 1, genres: 1 } 
) 

// Filtra el catalogo para extraer comedias romanticas que posean exactamente tres etiquetas de genero y 
// devuelve un listado con el titulo y los generos de cada pelicula, finalizando con un recuento total de las coincidencias

//------------------------------------------------------------------------------------------------
//4. 
// Liste las películas que no tengan el campo rated, o cuyo valor sea "UNRATED" o 
// "NOT RATED". Indique el conteo. 
//-------------------------------------------------------------------------------------------------

use('sample_mflix'); 

db.movies.find( 
  { $or: [ { rated: { $exists: false } }, { rated: { $in: ["UNRATED", "NOT RATED"] } } ] }, 
  { _id: 0, title: 1, rated: 1 } 
)

// Extrae todas las peliculas sin clasificar o con etiquetas de omision de restricciones de 
// edad y muestra sus titulos junto a su clasificación actual ademas calcula cuantas peliculas se encontraron en total

//------------------------------------------------------------------------------------------------
//5. 
//Liste los títulos que empiecen por "The" y terminen en "Man", sin distinguir mayúsculas 
// de minúsculas (expresión regular). 
//-------------------------------------------------------------------------------------------------
use('sample_mflix');

b.movies.find(  
	 { title: /^the.* man$/i },  
	 { _id: 0, title: 1 }  
)	

// Busca los titulos que empiezan con "The" y terminan en "Man", sin importar mayusculas o minusculas,
// y muestra los titulos y al final cuenta cuantos son

//Parte B


//------------------------------------------------------------------------------------------------
//6. 
// Para cada género calcule: número de películas, rating IMDb promedio (redondeado a 2 decimales) 
// y rating máximo. Muestre solo los géneros con más de 500 películas, ordenados por 
// promedio descendente. Nota: imdb.rating contiene valores vacíos (""); filtre únicamente valores numéricos. 
//-------------------------------------------------------------------------------------------------

use('sample_mflix'); 

db.movies.aggregate([ 
  { $match: { "imdb.rating": { $type: "number" } } }, 
  { $unwind: "$genres" }, 
  { $group: { 
      _id: "$genres", 
      peliculas: { $sum: 1 }, 
      promedio: { $avg: "$imdb.rating" }, 
      maximo: { $max: "$imdb.rating" } } }, 
  { $match: { peliculas: { $gt: 500 } } }, 
  { $project: { peliculas: 1, promedio: { $round: ["$promedio", 2] }, maximo: 1 } }, 
  { $sort: { promedio: -1 } } 
])

// Genera estadisticas de calificacion por genero para categorias con mas de 500 peliculas y
// muestra el nombre del genero, total de titulos, calificacion maxima y el promedio con dos decimales, 
// ordenando todo de mayor a menor


//------------------------------------------------------------------------------------------------
// 7. 
// Obtenga el Top 5 de directores con más películas con imdb.rating mayor o igual a 7.5
// (mínimo 5 películas). Muestre el director, la cantidad y una lista de máximo 3 títulos. 
//-------------------------------------------------------------------------------------------------

use('sample_mflix'); 

db.movies.aggregate([ 
  { $match: { "imdb.rating": { $gte: 7.5 } } }, 
  { $unwind: "$directors" }, 
  { $group: { _id: "$directors", cantidad: { $sum: 1 }, titulos: { $push: "$title" } } }, 
  { $match: { cantidad: { $gte: 5 } } }, 
  { $sort: { cantidad: -1 } }, 
  { $limit: 5 }, 
  { $project: { _id: 0, director: "$_id", cantidad: 1, titulos: { $slice: ["$titulos", 3] } } } 
])

// Muestra el Top 5 de directores con al menos 5 peliculas calificadas con un rating de 7.5 o mas,
// mostrando el nombre del director, su cantidad de peliculas destacadas y 3 de sus titulos.

//------------------------------------------------------------------------------------------------
// 8. 
// Obtenga el Top 5 de directores con más películas con imdb.rating mayor o igual a 7.5
// (mínimo 5 películas). Muestre el director, la cantidad y una lista de máximo 3 títulos. 
//-------------------------------------------------------------------------------------------------

use('sample_mflix'); 

db.movies.aggregate([ 
  { $match: { year: { $type: "number", $gte: 1950 } } }, 
  { $group: { 
      _id: { $subtract: ["$year", { $mod: ["$year", 10] }] }, 
      peliculas: { $sum: 1 } } }, 
  { $sort: { _id: 1 } }, 
  { $project: { _id: 0, decada: { $concat: [{ $toString: "$_id" }, "s"] }, peliculas: 1 } } ]) 

// Agrupa cronologicamente por decadas las peliculas desde 1950, cuenta sus totales y muestra el
// periodo como texto para la "s" de menor a mayor

//------------------------------------------------------------------------------------------------
// 9. 
// Obtenga el Top 10 de películas más comentadas: título, año y número de 
// comentarios (utilice $lookup entre comments y movies).  
//-------------------------------------------------------------------------------------------------

use('sample_mflix'); 

db.comments.aggregate([ 
  { $group: { _id: "$movie_id", comentarios: { $sum: 1 } } }, 
  { $sort: { comentarios: -1 } }, 
  { $limit: 10 }, 
  { $lookup: { from: "movies", localField: "_id", foreignField: "_id", as: "pelicula" } }, 
  { $unwind: "$pelicula" }, 
  { $project: { _id: 0, titulo: "$pelicula.title", anio: "$pelicula.year", comentarios: 1 } } 
]) 

// Vincula los comentarios con sus respectivas peliculas, cuenta el total por título y genera 
// un Top 10 de las producciones mas comentadas mostrando datos de titulo, año y comentarios

//------------------------------------------------------------------------------------------------
// 10. 
// Liste los usuarios (por email) con más de 250 comentarios, indicando la fecha 
// de su primer y último comentario. 
//-------------------------------------------------------------------------------------------------

use('sample_mflix'); 
db.comments.aggregate([ 
  { $group: { 
      _id: "$email", 
      comentarios: { $sum: 1 }, 
      primerComentario: { $min: "$date" }, 
      ultimoComentario: { $max: "$date" } } }, 
  { $match: { comentarios: { $gt: 250 } } }, 
  { $sort: { comentarios: -1 } } 
]) 

// Agrupa los comentarios por email y se queda con los usuarios que tienen mas de 250 y muestra 
// el email, la cantidad de comentarios y las fechas del primer y ultimo comentario,
// desde el mas activo al menos activo.

//Parte C

//------------------------------------------------------------------------------------------------
// 11. 
// Cree la colección peliculas_pareja mediante $out o $merge con las películas de 2015: título, 
// géneros, rating y un campo calculado categoria ("Alta" si rating ≥ 7.5, "Media" si ≥ 6, 
// "Baja" en otro caso) usando $switch.  
//-------------------------------------------------------------------------------------------------

use('sample_mflix'); 

db.createCollection("peliculas_pareja") 
db.movies.aggregate([ 
  {$match: {year: 2015, "imdb.rating": {$type: "number"}}}, 
  {$project: { 
      titulo: "$title", 
      generos: "$genres", 
      rating: "$imdb.rating", 
      categoria: { 
        $switch: { 
          branches: [ 
            { case: { $gte: ["$imdb.rating", 7.5] }, then: "Alta" }, 
            {case: {$gte: ["$imdb.rating", 6]}, then: "Media" } 
          ], 
          default: "Baja" 
        } 
      } 
  } }, 
  { $out: "peliculas_pareja"} 
]); 

//revicion si se creo 

use('sample_mflix'); 
db.peliculas_pareja.find(); 

// Genera una nueva coleccion con peliculas de 2015 clasificadas en tres niveles segun su 
// rating, mostrando estadisticas de la creacion y una muestra de los resultados 
// de menor puntuacion.


//------------------------------------------------------------------------------------------------
// 12. 
//Con updateMany agregue el campo revisado: true e incremente en 0.1 el rating de 
// las películas de categoría "Media". Reporte matchedCount y modifiedCount. 
//-------------------------------------------------------------------------------------------------

use('sample_mflix'); 

db.peliculas_pareja.updateMany( 
  { categoria: "Media" }, 
  { $set: { revisado: true }, $inc: { rating: 0.1 } } 
)   

// Actualiza las peliculas de categoria intermedia activando su bandera de revision e
// incrementando su rating en 0.1, reportando al final el total de registros coincidentes y modificados.

//------------------------------------------------------------------------------------------------
// 13. 
// Con deleteMany elimine las películas de categoría "Baja" y reporte cuántos documentos
// se borraron.  
//-------------------------------------------------------------------------------------------------

use('sample_mflix'); 

db.peliculas_pareja.deleteMany({ categoria: "Baja" })

// Borra de la coleccion todos los titulos clasificados como "Baja" y retorna el total 
// de bajas confirmadas para verificar la consistencia de los datos con el conteo anterior.

//------------------------------------------------------------------------------------------------
// 14. 
// Con deleteMany elimine las películas de categoría "Baja" y reporte cuántos documentos
// se borraron.  
//-------------------------------------------------------------------------------------------------

//ver los indices actuales
db.movies.getIndexes()

//explain ANTES del índice
db.movies.find(
  { genres: "Drama", year: { $gte: 2000, $lte: 2010 }, "imdb.rating": { $gte: 8 } },
  { _id: 0, title: 1, year: 1, "imdb.rating": 1 }
).sort({ "imdb.rating": -1 }).limit(10).explain("executionStats")

// rear el indice, Orden ESR: igualdad, orden y rango
db.movies.createIndex(
  { genres: 1, "imdb.rating": -1, year: 1 },
  { name: "idx_esr_punto14" }
)

// explain DESPUES del indice
db.movies.find(
  { genres: "Drama", year: { $gte: 2000, $lte: 2010 }, "imdb.rating": { $gte: 8 } },
  { _id: 0, title: 1, year: 1, "imdb.rating": 1 }
).sort({ "imdb.rating": -1 }).limit(10).explain("executionStats")

//eliminar el índice
db.movies.dropIndex("idx_esr_punto14")

// Evalúa el rendimiento de la busqueda de dramas mediante analisis de ejecucion (explain) 
// antes y despues de aplicar un indice compuesto de tres campos, reportando metricas 
// clave de eficiencia antes de remover dicho indice.