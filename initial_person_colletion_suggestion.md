the content belo offer a brief description of the person collection.

Person register:
   id: (authomatic mongo Id)
   cpf: (only numbers - 11 digits with 2 verified digits - the last ones)
   rg: 
      number:   (Alfa-numeric - some states use letters and numbers and a few special chacteres like -, ., etc)
      issued_by: (date - dd/mm/yyyy)
      issue_date: (date - dd/mm/yyyy)
   first_name:
   last_name:
   full_name:
   burthday:
   endereço:
        street_name:
        number:
        cep:
        tipo_logradouro:  (Rua, Avenida, Praça, ...)
        neighborhood:
        zipcode: (cep brazilian)
        state:   (SP, MG, ...)
        country: Brazil    
   membership_data:
        mother:
             id: 
             name: 
             cpf:
        father:
             id:
             name:
             cpf:  
        responsable_person:
             id:
             name:
             cpf: 
             kinship_degree:  
   beneficiary:
             card_number (Alfa-numeric - 10 digits)
             register_date: (date dd/mm/yyyy)  
   institution_relationships:soup
	types: [] // allows multiple types of relationships: examples: student_creche, student_cecor, basic_food, medical, oftalm, odont, psycology, psychology, psychiatry, soup, bazaar, ...   

 created_at: (date - dd/mm/yyyy)
 updated_at: (date - dd/mm/yyyy)       


Based on the provided initial_person_colletion_suggestion.md file, I'll create a JSON schema with validation specifications for all fields in the person collection.  

```json_schema
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Person Schema",
  "type": "object",
  "required": ["cpf", "first_name", "last_name", "full_name", "birthday", "endereco", "created_at"],
  "properties": {
    "id": {
      "description": "Automatic MongoDB ID",
      "type": "string"
    },
    "cpf": {
      "type": "string",
      "description": "Brazilian CPF - only numbers",
      "pattern": "^\\d{11}$",
      "minLength": 11,
      "maxLength": 11
    },
    "rg": {
      "type": "object",
      "properties": {
        "number": {
          "type": "string",
          "description": "RG number - alphanumeric with possible special characters",
          "pattern": "^[a-zA-Z0-9\\-\\.]+$"
        },
        "issued_by": {
          "type": "string",
          "description": "Issuing authority"
        },
        "issue_date": {
          "type": "string",
          "description": "Date of issue in dd/mm/yyyy format",
          "pattern": "^(0[1-9]|[12][0-9]|3[01])\\/(0[1-9]|1[0-2])\\/\\d{4}$"
        }
      }
    },
    "first_name": {
      "type": "string",
      "minLength": 1
    },
    "last_name": {
      "type": "string",
      "minLength": 1
    },
    "full_name": {
      "type": "string",
      "minLength": 3
    },
    "birthday": {
      "type": "string",
      "description": "Date in dd/mm/yyyy format",
      "pattern": "^(0[1-9]|[12][0-9]|3[01])\\/(0[1-9]|1[0-2])\\/\\d{4}$"
    },
    "endereco": {
      "type": "object",
      "properties": {
        "street_name": {
          "type": "string"
        },
        "number": {
          "type": ["string", "number"]
        },
        "cep": {
          "type": "string",
          "pattern": "^\\d{8}$",
          "description": "Brazilian CEP (postal code) - 8 digits without hyphen"
        },
        "tipo_logradouro": {
          "type": "string",
          "description": "Type of address (Rua, Avenida, Praça, etc.)",
          "enum": ["Rua", "Avenida", "Praça", "Alameda", "Estrada", "Rodovia", "Travessa", "Viela", "Outro"]
        },
        "neighborhood": {
          "type": "string"
        },
        "zipcode": {
          "type": "string",
          "pattern": "^\\d{8}$",
          "description": "Brazilian CEP (postal code) - 8 digits without hyphen"
        },
        "state": {
          "type": "string",
          "description": "Brazilian state abbreviation",
          "enum": ["AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", "MA", "MT", "MS", "MG", "PA", "PB", "PR", "PE", "PI", "RJ", "RN", "RS", "RO", "RR", "SC", "SP", "SE", "TO"]
        },
        "country": {
          "type": "string",
          "enum": ["Brazil"]
        }
      },
      "required": ["street_name", "number", "zipcode", "state", "country"]
    },
    "membership_data": {
      "type": "object",
      "properties": {
        "mother": {
          "type": "object",
          "properties": {
            "id": {
              "type": "string"
            },
            "name": {
              "type": "string"
            },
            "cpf": {
              "type": "string",
              "pattern": "^\\d{11}$"
            }
          }
        },
        "father": {
          "type": "object",
          "properties": {
            "id": {
              "type": "string"
            },
            "name": {
              "type": "string"
            },
            "cpf": {
              "type": "string",
              "pattern": "^\\d{11}$"
            }
          }
        },
        "responsable_person": {
          "type": "object",
          "properties": {
            "id": {
              "type": "string"
            },
            "name": {
              "type": "string"
            },
            "cpf": {
              "type": "string",
              "pattern": "^\\d{11}$"
            },
            "kinship_degree": {
              "type": "string",
              "description": "Relationship to the person"
            }
          }
        }
      }
    },
    "beneficiary": {
      "type": "object",
      "properties": {
        "card_number": {
          "type": "string",
          "description": "Alphanumeric card number - 10 digits",
          "pattern": "^[a-zA-Z0-9]{10}$",
          "minLength": 10,
          "maxLength": 10
        },
        "register_date": {
          "type": "string",
          "description": "Registration date in dd/mm/yyyy format",
          "pattern": "^(0[1-9]|[12][0-9]|3[01])\\/(0[1-9]|1[0-2])\\/\\d{4}$"
        }
      }
    },
    "institution_relationships": {
      "type": "object",
      "properties": {
        "types": {
          "type": "array",
          "description": "Types of relationships with the institution",
          "items": {
            "type": "string",
            "enum": [
              "student_creche", 
              "student_cecor", 
              "basic_food", 
              "medical", 
              "oftalm", 
              "odont", 
              "psycology", 
              "psychology", 
              "psychiatry", 
              "soup", 
              "bazaar"
            ]
          }
        }
      }
    },
    "created_at": {
      "type": "string",
      "description": "Creation date in dd/mm/yyyy format",
      "pattern": "^(0[1-9]|[12][0-9]|3[01])\\/(0[1-9]|1[0-2])\\/\\d{4}$"
    },
    "updated_at": {
      "type": "string",
      "description": "Last update date in dd/mm/yyyy format",
      "pattern": "^(0[1-9]|[12][0-9]|3[01])\\/(0[1-9]|1[0-2])\\/\\d{4}$"
    }
  },
  "additionalProperties": false
}
```  
This JSON schema includes:

1. Field types and requirements
2. Validation patterns for:
* CPF (11 digits)
* Dates in dd/mm/yyyy format
* CEP/zipcode (8 digits)
* RG number (alphanumeric with special characters)
* Card number (10 alphanumeric characters)
3. Enumerations for:
* Brazilian states
* Address types (tipo_logradouro)
* Institution relationship types
4. Required fields
5. Nested object structures that match the original document


The schema can be used for validation in MongoDB or with JSON schema validation libraries in your application.  

---  

given the cpf value is a number the has 2 virifier digits at the end,  there is a standard method in Brazil to calculate this 2 digits based on the first 9 digits.  how to specify this calculation. Does Json Schema offer some standard for that?  

JSON Schema itself doesn't provide a way to implement custom validation algorithms like the CPF verification digits calculation. The standard JSON Schema can only validate patterns, formats, lengths, and other basic constraints.

For validating Brazilian CPF numbers with their verification digits, you have a few options:

Application-level validation: Implement the CPF validation algorithm in your application code (Node.js, etc.)

Custom validators: If you're using a framework or library that extends JSON Schema with custom validators

MongoDB validation: Use MongoDB's custom validation expressions if you're storing directly in MongoDB

Here's how you might implement the CPF validation algorithm in JavaScript (which you could use in your application):  

```javascript
/**
 * Validates a Brazilian CPF number
 * @param {string} cpf - CPF number (11 digits as string)
 * @returns {boolean} - Whether the CPF is valid
 */
function validateCPF(cpf) {
  // Remove non-numeric characters
  cpf = cpf.replace(/[^\d]/g, '');
  
  // Check if it has 11 digits
  if (cpf.length !== 11) {
    return false;
  }
  
  // Check for known invalid CPFs (all same digits)
  if (/^(\d)\1{10}$/.test(cpf)) {
    return false;
  }
  
  // Calculate first verification digit
  let sum = 0;
  for (let i = 0; i < 9; i++) {
    sum += parseInt(cpf.charAt(i)) * (10 - i);
  }
  let remainder = sum % 11;
  let digit1 = remainder < 2 ? 0 : 11 - remainder;
  
  // Calculate second verification digit
  sum = 0;
  for (let i = 0; i < 10; i++) {
    sum += parseInt(cpf.charAt(i)) * (11 - i);
  }
  remainder = sum % 11;
  let digit2 = remainder < 2 ? 0 : 11 - remainder;
  
  // Check if calculated verification digits match the provided ones
  return digit1 === parseInt(cpf.charAt(9)) && digit2 === parseInt(cpf.charAt(10));
}

module.exports = { validateCPF };
```  
In your JSON Schema, you can still include the basic pattern validation:
```json
"cpf": {
  "type": "string",
  "description": "Brazilian CPF - only numbers with valid verification digits",
  "pattern": "^\\d{11}$",
  "minLength": 11,
  "maxLength": 11
}
```  

Then in your application code, you would use both the JSON Schema validation (for basic format) and the custom CPF validation function for the verification digits logic.  

If you're using MongoDB, you could implement a custom validator in your schema:  

```javascript

       const mongoose = require('mongoose');
const { validateCPF } = require('../utils/cpfValidator');

const personSchema = new mongoose.Schema({
  cpf: {
    type: String,
    required: true,
    validate: {
      validator: function(v) {
        return validateCPF(v);
      },
      message: props => `${props.value} is not a valid CPF!`
    }
  },
  // other fields...
});

module.exports = mongoose.model('Person', personSchema);
```  
This approach ensures that the CPF validation is properly implemented according to the Brazilian standard algorithm for verification digits, which JSON Schema alone cannot handle.  

---  

NOw, using the same way of thought, create a json_schema for a companies colletion. Intead of cpf use cnpj number, que has verifier digits too. Bat has different numbers of characteres and anothet valition calculus.   

I'll create a JSON schema for a companies collection, using CNPJ instead of CPF. The CNPJ (Cadastro Nacional da Pessoa Jurídica) is Brazil's National Registry of Legal Entities, which has 14 digits including 2 verification digits.

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Company Schema",
  "type": "object",
  "required": ["cnpj", "razao_social", "nome_fantasia", "endereco", "created_at"],
  "properties": {
    "id": {
      "description": "Automatic MongoDB ID",
      "type": "string"
    },
    "cnpj": {
      "type": "string",
      "description": "Brazilian CNPJ - only numbers with valid verification digits",
      "pattern": "^\\d{14}$",
      "minLength": 14,
      "maxLength": 14
    },
    "razao_social": {
      "type": "string",
      "description": "Legal name of the company",
      "minLength": 3
    },
    "nome_fantasia": {
      "type": "string",
      "description": "Trade name of the company",
      "minLength": 1
    },
    "inscricao_estadual": {
      "type": "string",
      "description": "State registration number"
    },
    "inscricao_municipal": {
      "type": "string",
      "description": "Municipal registration number"
    },
    "data_fundacao": {
      "type": "string",
      "description": "Foundation date in dd/mm/yyyy format",
      "pattern": "^(0[1-9]|[12][0-9]|3[01])\\/(0[1-9]|1[0-2])\\/\\d{4}$"
    },
    "porte": {
      "type": "string",
      "description": "Company size",
      "enum": ["MEI", "Microempresa", "Pequeno Porte", "Médio Porte", "Grande Porte"]
    },
    "atividade_principal": {
      "type": "object",
      "properties": {
        "codigo": {
          "type": "string",
          "description": "CNAE code (National Classification of Economic Activities)"
        },
        "descricao": {
          "type": "string",
          "description": "Description of the main activity"
        }
      }
    },
    "atividades_secundarias": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "codigo": {
            "type": "string",
            "description": "CNAE code"
          },
          "descricao": {
            "type": "string",
            "description": "Description of the secondary activity"
          }
        }
      }
    },
    "endereco": {
      "type": "object",
      "properties": {
        "logradouro": {
          "type": "string"
        },
        "numero": {
          "type": ["string", "number"]
        },
        "complemento": {
          "type": "string"
        },
        "cep": {
          "type": "string",
          "pattern": "^\\d{8}$",
          "description": "Brazilian CEP (postal code) - 8 digits without hyphen"
        },
        "tipo_logradouro": {
          "type": "string",
          "description": "Type of address (Rua, Avenida, Praça, etc.)",
          "enum": ["Rua", "Avenida", "Praça", "Alameda", "Estrada", "Rodovia", "Travessa", "Viela", "Outro"]
        },
        "bairro": {
          "type": "string"
        },
        "municipio": {
          "type": "string"
        },
        "uf": {
          "type": "string",
          "description": "Brazilian state abbreviation",
          "enum": ["AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", "MA", "MT", "MS", "MG", "PA", "PB", "PR", "PE", "PI", "RJ", "RN", "RS", "RO", "RR", "SC", "SP", "SE", "TO"]
        },
        "pais": {
          "type": "string",
          "default": "Brasil"
        }
      },
      "required": ["logradouro", "numero", "cep", "bairro", "municipio", "uf"]
    },
    "contato": {
      "type": "object",
      "properties": {
        "telefone": {
          "type": "string",
          "description": "Phone number with DDD",
          "pattern": "^\\d{10,11}$"
        },
        "email": {
          "type": "string",
          "format": "email"
        },
        "website": {
          "type": "string",
          "format": "uri"
        }
      }
    },
    "representante_legal": {
      "type": "object",
      "properties": {
        "nome": {
          "type": "string"
        },
        "cpf": {
          "type": "string",
          "pattern": "^\\d{11}$",
          "description": "CPF of the legal representative"
        },
        "cargo": {
          "type": "string",
          "description": "Position in the company"
        }
      }
    },
    "socios": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "nome": {
            "type": "string"
          },
          "cpf": {
            "type": "string",
            "pattern": "^\\d{11}$"
          },
          "qualificacao": {
            "type": "string",
            "description": "Partner qualification"
          },
          "data_entrada": {
            "type": "string",
            "description": "Entry date in dd/mm/yyyy format",
            "pattern": "^(0[1-9]|[12][0-9]|3[01])\\/(0[1-9]|1[0-2])\\/\\d{4}$"
          },
          "percentual_capital": {
            "type": "number",
            "description": "Percentage of capital ownership",
            "minimum": 0,
            "maximum": 100
          }
        }
      }
    },
    "situacao_cadastral": {
      "type": "string",
      "enum": ["Ativa", "Suspensa", "Inapta", "Baixada", "Nula"]
    },
    "regime_tributario": {
      "type": "string",
      "enum": ["Simples Nacional", "Lucro Presumido", "Lucro Real"]
    },
    "capital_social": {
      "type": "number",
      "description": "Company's capital in BRL",
      "minimum": 0
    },
    "institution_relationships": {
      "type": "object",
      "properties": {
        "types": {
          "type": "array",
          "description": "Types of relationships with the institution",
          "items": {
            "type": "string",
            "enum": [
              "fornecedor", 
              "parceiro", 
              "doador", 
              "prestador_servico",
              "cliente"
            ]
          }
        }
      }
    },
    "created_at": {
      "type": "string",
      "description": "Creation date in dd/mm/yyyy format",
      "pattern": "^(0[1-9]|[12][0-9]|3[01])\\/(0[1-9]|1[0-2])\\/\\d{4}$"
    },
    "updated_at": {
      "type": "string",
      "description": "Last update date in dd/mm/yyyy format",
      "pattern": "^(0[1-9]|[12][0-9]|3[01])\\/(0[1-9]|1[0-2])\\/\\d{4}$"
    }
  },
  "additionalProperties": false
}
```  
Similar to the CPF validation, the CNPJ validation algorithm would need to be implemented at the application level since JSON Schema doesn't support such complex validation. Here's a JavaScript function to validate CNPJ numbers:  
```javascript

     /**
 * Validates a Brazilian CNPJ number
 * @param {string} cnpj - CNPJ number (14 digits as string)
 * @returns {boolean} - Whether the CNPJ is valid
 */
function validateCNPJ(cnpj) {
  // Remove non-numeric characters
  cnpj = cnpj.replace(/[^\d]/g, '');
  
  // Check if it has 14 digits
  if (cnpj.length !== 14) {
    return false;
  }
  
  // Check for known invalid CNPJs (all same digits)
  if (/^(\d)\1{13}$/.test(cnpj)) {
    return false;
  }
  
  // Calculate first verification digit
  let size = cnpj.length - 2;
  let numbers = cnpj.substring(0, size);
  const digits = cnpj.substring(size);
  let sum = 0;
  let pos = size - 7;
  
  for (let i = size; i >= 1; i--) {
    sum += parseInt(numbers.charAt(size - i)) * pos--;
    if (pos < 2) {
      pos = 9;
    }
  }
  
  let result = sum % 11 < 2 ? 0 : 11 - (sum % 11);
  if (result !== parseInt(digits.charAt(0))) {
    return false;
  }
  
  // Calculate second verification digit
  size = size + 1;
  numbers = cnpj.substring(0, size);
  sum = 0;
  pos = size - 7;
  
  for (let i = size; i >= 1; i--) {
    sum += parseInt(numbers.charAt(size - i)) * pos--;
    if (pos < 2) {
      pos = 9;
    }
  }
  
  result = sum % 11 < 2 ? 0 : 11 - (sum % 11);
  
  return result === parseInt(digits.charAt(1));
}

module.exports = { validateCNPJ };
```  
If you're using MongoDB, you could implement a custom validator in your schema:
```javascript
 const mongoose = require('mongoose');
const { validateCNPJ } = require('../utils/cnpjValidator');

const companySchema = new mongoose.Schema({
  cnpj: {
    type: String,
    required: true,
    validate: {
      validator: function(v) {
        return validateCNPJ(v);
      },
      message: props => `${props.value} is not a valid CNPJ!`
    }
  },
  // other fields...
});

module.exports = mongoose.model('Company', companySchema);
```  

This schema includes all the essential fields for a Brazilian company, with appropriate validations for each field type. The CNPJ validation would need to be implemented separately as shown above since it requires a specific algorithm to validate the verification digits.  

JSON Schema files typically use the .json extension since they are written in JSON format. There is no special file extension specifically for JSON Schema files - they are simply JSON files that follow the JSON Schema specification.

Some projects might use naming conventions like schema.json or *-schema.json to indicate that a JSON file contains a schema definition, but the file extension itself remains .json.  

---  


             
