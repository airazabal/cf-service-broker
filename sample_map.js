let paths = [{
    'apiName': '/route',
    'targetUrl': 'https://here'
}, {
    'apiName': 'some'
}, {
    'apiName': ''
}];
let targetUrl="https://here"

console.log(paths[0]['apiName'])
let path = '';
for (var i = 0; i < paths.length; i++) {
    if (paths[i].targetUrl === targetUrl) {
        path = paths[i].apiName;
        break;
    }
}
console.log(path)
