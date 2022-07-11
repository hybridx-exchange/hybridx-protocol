const fs = require('fs')
const stripJsonComments = require('strip-json-comments')

const loadConfig = (path) =>{
    let config = JSON.parse(stripJsonComments(fs.readFileSync(path).toString()));
    return config
};

const saveConfig = (config, path) =>{
    fs.writeFileSync(path, JSON.stringify(config))
}

module.exports = {
    loadConfig,
    saveConfig
}