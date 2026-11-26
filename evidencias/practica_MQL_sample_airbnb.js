//1
use('sample_airbnb');
db.listingsAndReviews.insertOne({
    name:  "Cozy Cabin Retreat",
    summary: 'insert',
    property_type: "Cabin",
    price: 150.00
})

//2
use('sample_airbnb');
db.listingsAndReviews.insertOne({
    name:  "Cozy Cabin Retreat",
    property_type: "Cabin",
    price: 150.00,
    adress:{
        country: "Chile",
        market: "Santiago"
    }
})

//3
use('sample_airbnb');
db.listingsAndReviews.insertMany([
    {name: "Studio de Arte Urbano",summary:"Estudio con obras" ,price: 80.00},
    {name: "Loft Minimalista", summary:"Muy minimalista" , price: 110.00}
])

//4
use('sample_airbnb');
db.listingsAndReviews.insertMany([{
    name:"hola",
    amenities:["Wifi", "Kitchen", "Free parking", "Air conditioning"],
    price: 150.00
}])

//5
use('sample_airbnb');
db.listingsAndReviews.find({_id:'10030955'})
db.listingsAndReviews.insertOne({
    _id:"10030955",
    name: "validacion"
})


//6
use('sample_airbnb')
db.listingsAndReviews.find({"address.country": "Brazil"})

//7
use('sample_airbnb')
db.listingsAndReviews.find(
  { beds: { $gt: 5 } },
  { name: 1, number_of_reviews: 1}
)

//8
use('sample_airbnb')
db.listingsAndReviews.find(
  { price: { $lt: 75 } },
  { name: 1, price: 1, property_type: 1 }
)

//9
use('sample_airbnb')
db.listingsAndReviews.find({
  $and: [
    { property_type: "Apartment" },
    { "address.market": "New York" }
  ]
})

//10
use('sample_airbnb')
db.listingsAndReviews.find({
  property_type: { $in: ["House", "Condominium"] }
})

//11
use('sample_airbnb')
db.listingsAndReviews.find(
    { name: {$regex: "Luxury", $options: 'i'} }
)

//12
use('sample_airbnb')
db.listingsAndReviews.find(
    { amenities: "Heating" }
)

//13
use('sample_airbnb')
db.listingsAndReviews.find(
    { amenities: { $size: 20 }}
)

//14
use('sample_airbnb')
db.listingsAndReviews.find(
  {},
  { name: 1, price: 1, "address.country": 1 }
).sort({ price: -1 }).limit(10)