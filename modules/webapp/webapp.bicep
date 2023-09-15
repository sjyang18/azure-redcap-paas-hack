param webAppName string
// TODO: Rename to add Name
param appServicePlan string
param location string
param skuName string
param skuTier string
param tags object
param linuxFxVersion string
param dbHostName string
param dbName string

@secure()
param dbUserName string

@secure()
param dbPassword string
//param repoUrl string

//param logAnalyticsWorkspaceId string = ''
param peSubnetId string
param privateDnsZoneId string
param integrationSubnetId string
@secure()
param redcapZipUrl string
@secure()
param redcapCommunityUsername string
@secure()
param redcapCommunityPassword string
param scmRepoUrl string
param scmRepoBranch string = 'main'
param preRequsiteCommand string = 'apt-get install unzip -y && apt-get install -y python3 python3-pip'

resource appSrvcPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlan
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

var DBSslCa = '/home/site/wwwroot/DigiCertGlobalRootCA.crt.pem'

resource webApp 'Microsoft.Web/sites@2022-03-01' = {
  name: webAppName
  location: location
  tags: tags
  properties: {
    httpsOnly: true
    serverFarmId: appSrvcPlan.id
    virtualNetworkSubnetId: integrationSubnetId
    siteConfig: {
      alwaysOn: true
      http20Enabled: true

      linuxFxVersion: linuxFxVersion
      minTlsVersion: '1.2'
      ftpsState: 'FtpsOnly'
      appCommandLine: preRequsiteCommand
      appSettings: [
        {
          name: 'redcapAppZip'
          value: redcapZipUrl
        }
        {
          name: 'DBHostName'
          value: dbHostName
        }
        {
          name: 'DBName'
          value: dbName
        }
        {
          name: 'DBUserName'
          value: dbUserName
        }
        {
          name: 'DBPassword'
          value: dbPassword
        }
        {
          name: 'redcapCommunityUsername'
          value: redcapCommunityUsername
        }
        {
          name: 'redcapCommunityPassword'
          value: redcapCommunityPassword
        }
        {
          name: 'DBSslCa'
          value: DBSslCa
        }
        {
          name: 'smtpFQDN'
          value: ''
        }
        {
          name: 'smtpPort'
          value: ''
        }
        {
          name: 'fromEmailAddress'
          value: ''
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: '1'
        } 
      ]
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// TODO: App Insights does not appear linked to web app
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  // TODO: Get name from name generator module
  name: 'appInsights-${webAppName}'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    // TODO: This deploys Classic App Insights; must use Workspace-based now
    //WorkspaceResourceId: logAnalyticsWorkspaceId
    Flow_Type: 'Bluefield'
  }
}

resource webSiteName_web 'Microsoft.Web/sites/sourcecontrols@2015-08-01' = {
  parent: webApp
  name: 'web'
  location: location
  tags: {
    displayName: 'CodeDeploy'
  }
  properties: {
    repoUrl: scmRepoUrl
    branch: scmRepoBranch
    isManualIntegration: true
  }
}

resource peWebApp 'Microsoft.Network/privateEndpoints@2022-07-01' = {
  // TODO: Inconsistent
  name: 'pe-webAppName'
  location: location
  properties: {
    subnet: {
      id: peSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'pe-${webAppName}'
        properties: {
          privateLinkServiceId: webApp.id
          groupIds: [
            'sites'
          ]
        }
      }
    ]
  }
}

resource privateDnsZoneGroupsWebApp 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-07-01' = {
  name: 'privatednszonegroup'
  parent: peWebApp
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'pe-${webAppName}'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

output webAppIdentity string = webApp.identity.principalId
