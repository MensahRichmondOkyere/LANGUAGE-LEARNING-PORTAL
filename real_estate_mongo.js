// Filename: real_estate_mongo.js
// MongoDB 6+
// Database for a real estate website: users/agents, properties, inquiries, appointments

use('real_estate');

// Users (agents & clients)
db.createCollection('users', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['full_name','email','role','created_at'],
      properties: {
        full_name: { bsonType: 'string', minLength: 1 },
        email: { bsonType: 'string', pattern: '^.+@.+\\..+$' },
        phone: { bsonType: 'string' },
        role: { enum: ['AGENT','CLIENT','ADMIN'] },
        created_at: { bsonType: 'date' }
      }
    }
  }
});
db.users.createIndex({ email: 1 }, { unique: true, name: 'ux_users_email' });

// Properties
db.createCollection('properties', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['title','type','status','price','location','address','agent_id','created_at'],
      properties: {
        title: { bsonType: 'string' },
        description: { bsonType: 'string' },
        type: { enum: ['HOUSE','APARTMENT','LAND','COMMERCIAL'] },
        status: { enum: ['FOR_SALE','SOLD','FOR_RENT','RENTED'] },
        bedrooms: { bsonType: ['int','null'], minimum: 0 },
        bathrooms: { bsonType: ['int','null'], minimum: 0 },
        area_sqft: { bsonType: ['int','null'], minimum: 0 },
        price: { bsonType: ['int','long','double'], minimum: 0 },
        amenities: { bsonType: ['array','null'], items: { bsonType: 'string' } },
        images: { bsonType: ['array','null'], items: { bsonType: 'string' } },
        address: {
          bsonType: 'object',
          required: ['street','city','state','country'],
          properties: {
            street: { bsonType: 'string' },
            city: { bsonType: 'string' },
            state: { bsonType: 'string' },
            postal_code: { bsonType: ['string','null'] },
            country: { bsonType: 'string' }
          }
        },
        location: {
          bsonType: 'object',
          required: ['type','coordinates'],
          properties: {
            type: { enum: ['Point'] },
            coordinates: { bsonType: 'array', items: { bsonType: 'double' }, minItems: 2, maxItems: 2 }
          }
        },
        agent_id: { bsonType: 'objectId' },
        created_at: { bsonType: 'date' },
        updated_at: { bsonType: ['date','null'] }
      }
    }
  }
});
db.properties.createIndex({ location: "2dsphere" }, { name: 'gx_properties_location' });
db.properties.createIndex({ status: 1, type: 1, price: 1 }, { name: 'ix_status_type_price' });
db.properties.createIndex({ 'address.city': 1 }, { name: 'ix_city' });
db.properties.createIndex({ title: 'text', description: 'text' }, { name: 'tx_title_description' });

// Inquiries (lead messages about a property)
db.createCollection('inquiries', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['property_id','name','email','message','created_at','status'],
      properties: {
        property_id: { bsonType: 'objectId' },
        name: { bsonType: 'string' },
        email: { bsonType: 'string', pattern: '^.+@.+\\..+$' },
        phone: { bsonType: ['string','null'] },
        message: { bsonType: 'string' },
        status: { enum: ['NEW','CONTACTED','CLOSED'] },
        created_at: { bsonType: 'date' }
      }
    }
  }
});
db.inquiries.createIndex({ property_id: 1, created_at: -1 }, { name: 'ix_prop_created' });

// Appointments (viewings)
db.createCollection('appointments', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['property_id','agent_id','scheduled_at','attendee_name','created_at'],
      properties: {
        property_id: { bsonType: 'objectId' },
        agent_id: { bsonType: 'objectId' },
        scheduled_at: { bsonType: 'date' },
        attendee_name: { bsonType: 'string' },
        attendee_phone: { bsonType: ['string','null'] },
        attendee_email: { bsonType: ['string','null'] },
        created_at: { bsonType: 'date' }
      }
    }
  }
});
db.appointments.createIndex({ agent_id: 1, scheduled_at: -1 }, { name: 'ix_agent_schedule' });
db.appointments.createIndex({ property_id: 1, scheduled_at: -1 }, { name: 'ix_property_schedule' });

// Seed data
const agentId = db.users.insertOne({
  full_name: 'Ama Mensah',
  email: 'ama.agent@example.com',
  phone: '+233555000111',
  role: 'AGENT',
  created_at: new Date()
}).insertedId;

const clientId = db.users.insertOne({
  full_name: 'Kojo Owusu',
  email: 'kojo.client@example.com',
  phone: '+233555000222',
  role: 'CLIENT',
  created_at: new Date()
}).insertedId;

const prop1 = db.properties.insertOne({
  title: '3-Bedroom House in East Legon',
  description: 'Spacious house with modern kitchen and garden.',
  type: 'HOUSE',
  status: 'FOR_SALE',
  bedrooms: 3,
  bathrooms: 2,
  area_sqft: 2200,
  price: 250000,
  amenities: ['Garden','Parking','Air Conditioning'],
  images: [],
  address: { street: '12 Palm St', city: 'Accra', state: 'Greater Accra', postal_code: '00233', country: 'Ghana' },
  location: { type: 'Point', coordinates: [-0.1667, 5.6167] },
  agent_id: agentId,
  created_at: new Date()
}).insertedId;

db.inquiries.insertOne({
  property_id: prop1,
  name: 'Kojo Owusu',
  email: 'kojo.client@example.com',
  phone: '+233555000222',
  message: 'Is this house still available? Can I schedule a viewing?',
  status: 'NEW',
  created_at: new Date()
});

db.appointments.insertOne({
  property_id: prop1,
  agent_id: agentId,
  scheduled_at: new Date(Date.now() + 3*24*60*60*1000),
  attendee_name: 'Kojo Owusu',
  attendee_phone: '+233555000222',
  attendee_email: 'kojo.client@example.com',
  created_at: new Date()
});

// Example queries
// Nearby properties within 5km
const nearby = db.properties.aggregate([
  { $geoNear: {
      near: { type: 'Point', coordinates: [-0.186964, 5.603717] },
      distanceField: 'distance_m',
      maxDistance: 5000,
      spherical: true
  }},
  { $project: { title: 1, price: 1, 'address.city': 1, distance_m: 1 } }
]);
printjson(nearby.toArray());

// Search by text
const search = db.properties.find({ $text: { $search: 'garden modern' } }, { score: { $meta: 'textScore' } }).sort({ score: { $meta: 'textScore' } });
printjson(search.toArray());
